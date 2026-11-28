import { useCallback, useEffect, useRef, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { Bell, Check } from 'lucide-react'
import { notificationTarget, relativeTime, type NotificationData } from './notifications-helpers'
import './notifications.css'

export type AdminNotification = {
  id: string
  type: string
  title: string
  body: string
  data?: NotificationData
  readAt: string | null
  createdAt: string
}
type NotificationsResponse = {
  items: AdminNotification[]
  unreadCount: number
  nextCursor: string | null
}
type Api = <T>(path: string, init?: RequestInit) => Promise<T>

const POLL_MS = 30_000

export default function NotificationsBell({ api }: { api: Api }) {
  const navigate = useNavigate()
  const [items, setItems] = useState<AdminNotification[]>([])
  const [unreadCount, setUnreadCount] = useState(0)
  const [open, setOpen] = useState(false)
  const inFlight = useRef(false)

  const load = useCallback(async () => {
    if (inFlight.current) return
    inFlight.current = true
    try {
      const result = await api<NotificationsResponse>('/admin/notifications?limit=20')
      setItems(result.items)
      setUnreadCount(result.unreadCount)
    } catch {
      // Network errors are silent: the bell keeps its previous state.
    } finally {
      inFlight.current = false
    }
  }, [api])

  useEffect(() => {
    void load()
    const timer = window.setInterval(() => {
      if (document.visibilityState === 'visible') void load()
    }, POLL_MS)
    const onVisible = () => {
      if (document.visibilityState === 'visible') void load()
    }
    document.addEventListener('visibilitychange', onVisible)
    return () => {
      window.clearInterval(timer)
      document.removeEventListener('visibilitychange', onVisible)
    }
  }, [load])

  const markOne = async (item: AdminNotification) => {
    try {
      await api(`/admin/notifications/${item.id}/read`, { method: 'PATCH' })
      setItems((current) => current.map((n) => (n.id === item.id ? { ...n, readAt: n.readAt ?? new Date().toISOString() } : n)))
      setUnreadCount((current) => Math.max(0, current - (item.readAt ? 0 : 1)))
      setOpen(false)
      const target = notificationTarget(item.data)
      navigate(target.to, { state: target.state })
    } catch {
      // Keep the item unchanged when the request fails.
    }
  }

  const markAll = async () => {
    try {
      await api('/admin/notifications/read-all', { method: 'POST' })
      setItems((current) => current.map((n) => ({ ...n, readAt: n.readAt ?? new Date().toISOString() })))
      setUnreadCount(0)
    } catch {
      // Silent failure.
    }
  }

  return (
    <div className="notification-popover">
      <button className="icon-button notification-button" aria-label="Notifications" onClick={() => { setOpen((v) => !v); if (!open) void load() }}>
        <Bell size={18} />
        {unreadCount > 0 && <b data-testid="notification-count">{unreadCount}</b>}
      </button>
      {open && (
        <div className="notification-panel" role="dialog" aria-label="Recent notifications">
          <div className="notification-panel-head">
            <strong>Notifications</strong>
            <button className="button button-outline button-tiny" onClick={() => void markAll()}><Check size={13} /> Mark all as read</button>
          </div>
          {items.length === 0 && <div className="empty-inline">No new notifications.</div>}
          {items.slice(0, 20).map((item) => (
            <button key={item.id} className="notification-item" onClick={() => void markOne(item)}>
              <span className={`notification-dot ${item.readAt ? '' : 'unread'}`} />
              <span><strong>{item.title}</strong><small>{item.body}</small><small className="muted">{relativeTime(item.createdAt)}</small></span>
            </button>
          ))}
        </div>
      )}
    </div>
  )
}
