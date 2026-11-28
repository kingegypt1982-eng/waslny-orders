export type NotificationData = { role?: string; userId?: string } | null | undefined

export function relativeTime(iso: string, now = Date.now()): string {
  const diff = Math.max(0, now - new Date(iso).getTime())
  const minutes = Math.floor(diff / 60_000)
  if (minutes < 1) return 'just now'
  if (minutes < 60) return `${minutes}m ago`
  const hours = Math.floor(minutes / 60)
  if (hours < 24) return `${hours}h ago`
  return `${Math.floor(hours / 24)}d ago`
}

export function notificationTarget(data: NotificationData): { to: string; state?: { highlight?: string } } {
  const userId = data?.userId
  if (data?.role === 'CAPTAIN' && userId) return { to: `/captains/${userId}` }
  if (userId) return { to: '/clients', state: { highlight: userId } }
  return { to: '/clients' }
}
