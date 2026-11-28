import { afterEach, describe, expect, it, vi } from 'vitest'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import { MemoryRouter, useLocation } from 'react-router-dom'
import NotificationsBell from './NotificationsBell'

const items = [
  { id: 'n1', type: 'CAPTAIN_REGISTERED', title: 'New captain awaiting review', body: 'Captain One signed up as a captain.', data: { role: 'CAPTAIN', userId: 'u1' }, readAt: null, createdAt: new Date().toISOString() },
  { id: 'n2', type: 'CLIENT_REGISTERED', title: 'New client registered', body: 'Client One signed up as a client.', data: { role: 'CLIENT', userId: 'u2' }, readAt: null, createdAt: new Date().toISOString() },
]

const api = vi.fn(async (path: string, init?: RequestInit) => {
  if (path.startsWith('/admin/notifications?')) return { items, unreadCount: 2, nextCursor: null }
  if (path.endsWith('/read')) return { marked: 1 }
  if (path.endsWith('/read-all')) return { marked: 2 }
  throw new Error(`unexpected ${path} ${init?.method ?? 'GET'}`)
}) as any

function LocationProbe() {
  const location = useLocation()
  return <span data-testid="location">{location.pathname}</span>
}

describe('NotificationsBell', () => {
  afterEach(() => cleanup())

  it('shows the unread count', async () => {
    render(<MemoryRouter><NotificationsBell api={api} /></MemoryRouter>)
    await waitFor(() => expect(screen.getByTestId('notification-count').textContent).toBe('2'))
  })

  it('marks one notification read and navigates to the captain', async () => {
    api.mockClear()
    render(<MemoryRouter><NotificationsBell api={api} /><LocationProbe /></MemoryRouter>)
    await waitFor(() => expect(screen.getByTestId('notification-count')).toBeTruthy())
    fireEvent.click(screen.getByLabelText('Notifications'))
    await waitFor(() => expect(screen.getByText('New captain awaiting review')).toBeTruthy())
    fireEvent.click(screen.getByText('New captain awaiting review'))
    await waitFor(() => expect(screen.getByTestId('location').textContent).toBe('/captains/u1'))
    expect(api).toHaveBeenCalledWith('/admin/notifications/n1/read', { method: 'PATCH' })
  })

  it('marks everything as read', async () => {
    api.mockClear()
    render(<MemoryRouter><NotificationsBell api={api} /></MemoryRouter>)
    await waitFor(() => expect(screen.getByTestId('notification-count')).toBeTruthy())
    fireEvent.click(screen.getByLabelText('Notifications'))
    fireEvent.click(screen.getByText('Mark all as read'))
    await waitFor(() => expect(screen.queryByTestId('notification-count')).toBeNull())
    expect(api).toHaveBeenCalledWith('/admin/notifications/read-all', { method: 'POST' })
  })
})
