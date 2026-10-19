import { useEffect, useState } from 'react'
import { Link, NavLink, Outlet, Route, Routes, useLocation, useParams } from 'react-router-dom'
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { Activity, ArrowRight, ArrowUpRight, Bell, Bike, Boxes, Check, ChevronDown, CircleDollarSign, ClipboardList, Download, Eye, LayoutDashboard, LifeBuoy, Menu, MoreHorizontal, Search, Settings2, ShieldCheck, Users, WalletCards, X } from 'lucide-react'
import { Area, AreaChart, CartesianGrid, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import './dashboard.css'

type Order = { id: string; reference: string; status: string; pickupLabel: string; deliveryLabel: string; price: number; createdAt: string; client?: { name: string }; captain?: { id?: string; name: string } | null }
type Captain = {
  id: string; status: string; vehicleType: string; vehiclePlate: string; createdAt: string
  nationalIdDocument: string; nationalIdBackDocument?: string; licenseDocument: string; licenseBackDocument?: string
  vehicleDocument: string; vehicleBackDocument?: string; profilePhotoDocument?: string
  nationalIdLast4?: string | null; dateOfBirth?: string | null; governorate?: string | null
  licenseNumber?: string | null; vehicleRegistrationNumber?: string | null
  vehicleMake?: string | null; vehicleModel?: string | null; vehicleColor?: string | null
  rejectionReason?: string | null; approvedAt?: string | null; reviewedAt?: string | null
  user: { id: string; name: string; email: string; phone?: string | null; wallet?: { balance: number } | null }
}
type Client = { id: string; name: string; email: string; phone?: string; suspendedAt?: string | null; createdAt?: string; _count?: { clientOrders: number } }
type WalletRecord = { id: string; name: string; email: string; wallet: { balance: number } | null; walletTransactions: { id: string; amount: number; type: string; createdAt: string; note?: string | null }[] }
type DashboardData = { clients: number; captains: number; pendingCaptains: number; openOrders: number; completedOrders: number; revenue: number; commission: number; recentOrders: Order[] }
type Pricing = { basePrice: number; pricePerKm: number; commissionPercent: number; minimumWalletBalance: number }

const ordersDemo: Order[] = [
  { id: 'o1', reference: 'WS-20481', status: 'ON_THE_WAY', pickupLabel: 'Dokki, Giza', deliveryLabel: 'Zamalek, Cairo', price: 94, createdAt: '2026-10-09T10:12:00', client: { name: 'Nour Studio' }, captain: { name: 'Omar Hassan' } },
  { id: 'o2', reference: 'WS-20480', status: 'SEARCHING_CAPTAIN', pickupLabel: 'Nasr City, Cairo', deliveryLabel: 'New Cairo', price: 168, createdAt: '2026-10-09T09:48:00', client: { name: 'Delta Auto' } },
  { id: 'o3', reference: 'WS-20479', status: 'DELIVERED', pickupLabel: 'Mohandessin, Giza', deliveryLabel: 'Maadi, Cairo', price: 132, createdAt: '2026-10-09T09:18:00', client: { name: 'Mina Pharmacy' }, captain: { name: 'Salma Adel' } },
  { id: 'o4', reference: 'WS-20478', status: 'ACCEPTED', pickupLabel: 'Heliopolis, Cairo', deliveryLabel: 'Sheraton, Cairo', price: 76, createdAt: '2026-10-09T08:56:00', client: { name: 'Studio 9' }, captain: { name: 'Karim Fathy' } },
  { id: 'o5', reference: 'WS-20477', status: 'COMPLETED', pickupLabel: 'Agouza, Giza', deliveryLabel: 'Garden City, Cairo', price: 110, createdAt: '2026-10-09T08:20:00', client: { name: 'Paper House' }, captain: { name: 'Youssef Ali' } },
]
const captainsDemo: Captain[] = [
  { id: 'c1', status: 'PENDING', vehicleType: 'Motorcycle', vehiclePlate: 'س ن د ٤٢١', createdAt: '2026-10-09', nationalIdDocument: '#', licenseDocument: '#', vehicleDocument: '#', user: { id: 'u1', name: 'Mahmoud Nabil', email: 'mahmoud@example.com', wallet: { balance: 0 } } },
  { id: 'c2', status: 'ACTIVE', vehicleType: 'Car', vehiclePlate: 'ق ر ب ٩٠٢', createdAt: '2026-10-08', nationalIdDocument: '#', licenseDocument: '#', vehicleDocument: '#', user: { id: 'u2', name: 'Salma Adel', email: 'salma@example.com', wallet: { balance: 340 } } },
  { id: 'c3', status: 'ACTIVE', vehicleType: 'Motorcycle', vehiclePlate: 'م ن ب ١٧٧', createdAt: '2026-10-07', nationalIdDocument: '#', licenseDocument: '#', vehicleDocument: '#', user: { id: 'u3', name: 'Omar Hassan', email: 'omar@example.com', wallet: { balance: 215 } } },
]
const clientsDemo: Client[] = [
  { id: 'u4', name: 'Delta Auto', email: 'ops@deltaauto.example', phone: '+201002223333', _count: { clientOrders: 18 } },
  { id: 'u5', name: 'Nour Studio', email: 'hello@nour.example', _count: { clientOrders: 12 } },
  { id: 'u6', name: 'Mina Pharmacy', email: 'mina@example.com', phone: '+201115554444', _count: { clientOrders: 9 } },
]
const dashboardDemo: DashboardData = { clients: 284, captains: 42, pendingCaptains: 6, openOrders: 18, completedOrders: 1268, revenue: 184520, commission: 18452, recentOrders: ordersDemo.slice(0, 4) }
const weekly = [{ day: '03 Oct', revenue: 2440 }, { day: '04 Oct', revenue: 3100 }, { day: '05 Oct', revenue: 2840 }, { day: '06 Oct', revenue: 4120 }, { day: '07 Oct', revenue: 3690 }, { day: '08 Oct', revenue: 4830 }, { day: '09 Oct', revenue: 4210 }]
const navigation = [
  { label: 'Overview', to: '/', icon: LayoutDashboard }, { label: 'Orders', to: '/orders', icon: ClipboardList, badge: '18' },
  { label: 'Captains', to: '/captains', icon: Bike, badge: '6' }, { label: 'Clients', to: '/clients', icon: Users },
  { label: 'Wallets', to: '/wallets', icon: WalletCards }, { label: 'Reports', to: '/reports', icon: Activity },
]

async function api<T>(path: string, init?: RequestInit): Promise<T> {
  const token = localStorage.getItem('wasalny-admin-token')
  const response = await fetch(`${import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1'}${path}`, {
    ...init, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...init?.headers },
  })
  if (!response.ok) throw new Error((await response.json().catch(() => ({}))).message ?? `Request failed (${response.status})`)
  return response.json() as Promise<T>
}
function useData<T>(key: string, path: string, fallback: T) {
  return useQuery({ queryKey: [key], queryFn: () => localStorage.getItem('wasalny-admin-token') ? api<T>(path) : Promise.resolve(fallback) })
}

function Frame() {
  const [menuOpen, setMenuOpen] = useState(false)
  const location = useLocation()
  const section = location.pathname.startsWith('/captains') ? 'Captains' : navigation.find((item) => item.to === location.pathname)?.label ?? (location.pathname === '/pricing' ? 'Pricing' : 'Settings')
  return <div className="shell"><aside className={`sidebar ${menuOpen ? 'sidebar-open' : ''}`}>
    <Link to="/" className="brand" onClick={() => setMenuOpen(false)}><span className="brand-mark"><Boxes size={19} /></span>wasalny<span className="brand-light">orders</span></Link>
    <div className="workspace"><span className="workspace-avatar">W</span><span><strong>Wasalny Logistics</strong><small>Operations workspace</small></span><ChevronDown size={15} /></div>
    <span className="nav-caption">WORKSPACE</span><nav className="main-nav">{navigation.map(({ label, to, icon: Icon, badge }) => <NavLink key={to} to={to} end={to === '/'} onClick={() => setMenuOpen(false)} className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}><Icon size={18} /><span>{label}</span>{badge && <b>{badge}</b>}</NavLink>)}</nav>
    <span className="nav-caption nav-caption-bottom">MANAGE</span><nav className="main-nav"><NavLink to="/pricing" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}><CircleDollarSign size={18} /><span>Pricing</span></NavLink><NavLink to="/settings" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}><Settings2 size={18} /><span>Settings</span></NavLink></nav>
    <div className="sidebar-bottom"><div className="help-row"><span className="help-icon"><LifeBuoy size={17} /></span><span><strong>Need a hand?</strong><small>Visit the help center</small></span></div><div className="account-row"><span className="account-avatar">AM</span><span><strong>Admin Manager</strong><small>Administrator</small></span><MoreHorizontal size={18} /></div></div>
  </aside>{menuOpen && <button className="mobile-scrim" onClick={() => setMenuOpen(false)} aria-label="Close navigation" />}
    <main className="main-area"><header className="topbar"><div className="topbar-left"><button className="icon-button mobile-menu" onClick={() => setMenuOpen(true)} aria-label="Open navigation"><Menu size={19} /></button><span className="breadcrumb">Workspace <span>/</span> <strong>{section}</strong></span></div><div className="topbar-actions"><span className="live-indicator"><i /> All systems operational</span><button className="icon-button notification-button" aria-label="Notifications"><Bell size={18} /><i /></button><span className="topbar-divider" /><button className="top-user" aria-label="Administrator menu"><span className="account-avatar">AM</span><ChevronDown size={14} /></button></div></header><div className="page-content"><Outlet /></div></main>
  </div>
}
function Heading({ eyebrow, title, description, action }: { eyebrow: string; title: string; description: string; action?: React.ReactNode }) {
  return <div className="page-heading"><div><div className="eyebrow">{eyebrow}</div><h1>{title}</h1><p>{description}</p></div>{action}</div>
}
function Metric({ label, value, change, icon: Icon, tone = 'mint' }: { label: string; value: string; change: string; icon: typeof Users; tone?: string }) {
  return <article className="metric-card"><div className="metric-top"><span>{label}</span><span className={`metric-icon ${tone}`}><Icon size={17} /></span></div><div className="metric-value">{value}</div><div className="metric-foot"><span className="trend"><ArrowUpRight size={13} />{change}</span><span>vs last week</span></div></article>
}
function Status({ value }: { value: string }) {
  const labels: Record<string, string> = { PENDING: 'Pending', SEARCHING_CAPTAIN: 'Finding captain', ACCEPTED: 'Accepted', ARRIVED_AT_PICKUP: 'At pickup', PICKED_UP: 'Picked up', ON_THE_WAY: 'On the way', DELIVERED: 'Delivered', COMPLETED: 'Completed', CANCELLED: 'Cancelled', ACTIVE: 'Approved', REJECTED: 'Rejected', SUSPENDED: 'Suspended' }
  return <span className={`status status-${value.toLowerCase()}`}><i />{labels[value] ?? value}</span>
}
function OrdersTable({ rows }: { rows: Order[] }) {
  return <div className="table-scroll"><table><thead><tr><th>ORDER</th><th>ROUTE</th><th>CLIENT</th><th>CAPTAIN</th><th>VALUE</th><th>STATUS</th><th /></tr></thead><tbody>{rows.map((row) => <tr key={row.id}><td><strong className="mono">{row.reference}</strong><small>{new Date(row.createdAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</small></td><td><div className="route-cell"><span>{row.pickupLabel}</span><span>{row.deliveryLabel}</span></div></td><td>{row.client?.name ?? '—'}</td><td>{row.captain?.name ?? <span className="muted">Unassigned</span>}</td><td className="amount">EGP {Number(row.price).toFixed(0)}</td><td><Status value={row.status} /></td><td><button className="row-menu" aria-label={`More actions ${row.reference}`}><MoreHorizontal size={18} /></button></td></tr>)}</tbody></table></div>
}
function Toolbar({ value, setValue, placeholder }: { value: string; setValue: (value: string) => void; placeholder: string }) {
  return <div className="table-toolbar"><label className="search-field"><Search size={16} /><input value={value} onChange={(event) => setValue(event.target.value)} placeholder={placeholder} /></label><button className="icon-button filter-button" aria-label="Filter results"><Activity size={16} /></button></div>
}

function Overview() {
  const { data = dashboardDemo } = useData<DashboardData>('dashboard', '/admin/dashboard', dashboardDemo)
  const { data: rows = ordersDemo } = useData<Order[]>('orders', '/admin/orders', ordersDemo)
  const demo = !localStorage.getItem('wasalny-admin-token')
  return <><Heading eyebrow="THURSDAY, 09 OCTOBER 2026" title="Good morning, team" description="Here's what's moving across Wasalny today." action={<div className="heading-actions"><span className={`sync-state ${demo ? 'demo-state' : ''}`}><i />{demo ? 'Sample workspace' : 'Live data'}</span><button className="button button-outline" onClick={() => window.print()}><Download size={15} /> Export</button></div>} />
    <section className="metric-grid"><Metric label="Gross delivery value" value={`EGP ${Number(data.revenue).toLocaleString()}`} change="12.8%" icon={CircleDollarSign} /><Metric label="Orders in progress" value={String(data.openOrders)} change="8.2%" icon={ClipboardList} tone="blue" /><Metric label="Active captains" value={String(data.captains)} change="4.6%" icon={Bike} tone="orange" /><Metric label="Registered clients" value={String(data.clients)} change="2.1%" icon={Users} tone="rose" /></section>
    <section className="overview-grid"><article className="panel activity-panel"><div className="panel-heading"><div><div className="panel-kicker">PERFORMANCE</div><h2>Delivery activity</h2></div><button className="select-control">Last 7 days <ChevronDown size={14} /></button></div><div className="chart-legend"><span><i className="legend-revenue" />Delivery value</span><strong>EGP 24,230 <small>+14.2%</small></strong></div><div className="chart-wrap"><ResponsiveContainer width="100%" height="100%"><AreaChart data={weekly} margin={{ top: 10, right: 8, left: -18, bottom: 0 }}><defs><linearGradient id="fill" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stopColor="#3ca889" stopOpacity={.18} /><stop offset="100%" stopColor="#3ca889" stopOpacity={.01} /></linearGradient></defs><CartesianGrid vertical={false} stroke="#edf0ed" strokeDasharray="3 4" /><XAxis dataKey="day" tickLine={false} axisLine={false} tick={{ fill: '#929b94', fontSize: 11 }} /><YAxis tickLine={false} axisLine={false} tick={{ fill: '#929b94', fontSize: 11 }} tickFormatter={(value: number) => `${value / 1000}k`} /><Tooltip formatter={(value) => [`EGP ${Number(value).toLocaleString()}`, 'Delivery value']} /><Area type="monotone" dataKey="revenue" stroke="#23886d" strokeWidth={2.5} fill="url(#fill)" activeDot={{ r: 4 }} /></AreaChart></ResponsiveContainer></div></article>
      <article className="panel attention-panel"><div className="panel-heading"><div><div className="panel-kicker">NEEDS ATTENTION</div><h2>On your radar</h2></div><span className="attention-count">{data.pendingCaptains + 2}</span></div><div className="attention-list"><Link to="/captains" className="attention-item"><span className="attention-icon attention-amber"><ShieldCheck size={17} /></span><span><strong>Captain applications</strong><small>{data.pendingCaptains} waiting for review</small></span><ArrowRight size={16} /></Link><Link to="/orders" className="attention-item"><span className="attention-icon attention-blue"><ClipboardList size={17} /></span><span><strong>Orders need a captain</strong><small>2 orders searching for 15+ min</small></span><ArrowRight size={16} /></Link><Link to="/wallets" className="attention-item"><span className="attention-icon attention-coral"><WalletCards size={17} /></span><span><strong>Low captain balances</strong><small>4 captains below EGP 50</small></span><ArrowRight size={16} /></Link></div><div className="attention-footer"><span><i /> All other operations are on track</span></div></article></section>
    <section className="panel table-panel"><div className="panel-heading table-heading"><div><div className="panel-kicker">LIVE OPERATIONS</div><h2>Recent orders</h2></div><Link to="/orders" className="text-link">View all orders <ArrowRight size={15} /></Link></div><OrdersTable rows={rows.slice(0, 5)} /></section><div className="dashboard-foot"><span><i /> Updated just now</span><span>Delivery commission earned <strong>EGP {Number(data.commission).toLocaleString()}</strong> this month</span></div>
  </>
}
function OrdersPage() {
  const cache = useQueryClient()
  const [search, setSearch] = useState('')
  const { data = ordersDemo } = useData<Order[]>('orders', '/admin/orders', ordersDemo)
  const { data: captains = captainsDemo } = useData<Captain[]>('captains', '/admin/captains', captainsDemo)
  const update = useMutation({ mutationFn: ({ id, changes }: { id: string; changes: { status?: string; captainId?: string } }) => api(`/admin/orders/${id}`, { method: 'PATCH', body: JSON.stringify(changes) }), onSuccess: () => cache.invalidateQueries({ queryKey: ['orders'] }) })
  const filtered = data.filter((row) => `${row.reference} ${row.pickupLabel} ${row.deliveryLabel} ${row.client?.name ?? ''}`.toLowerCase().includes(search.toLowerCase()))
  const editable = Boolean(localStorage.getItem('wasalny-admin-token'))
  const statuses = ['PENDING', 'SEARCHING_CAPTAIN', 'ACCEPTED', 'ARRIVED_AT_PICKUP', 'PICKED_UP', 'ON_THE_WAY', 'DELIVERED', 'COMPLETED', 'CANCELLED']
  return <><Heading eyebrow="DELIVERY OPERATIONS" title="Orders" description="Track every shipment from pickup request to completion." action={<button className="button button-outline" onClick={() => window.print()}><Download size={15} /> Export orders</button>} /><section className="panel table-panel"><Toolbar value={search} setValue={setSearch} placeholder="Search by order, place, or client" /><div className="table-scroll"><table><thead><tr><th>ORDER</th><th>ROUTE</th><th>CLIENT</th><th>VALUE</th><th>STATUS</th><th>CAPTAIN</th></tr></thead><tbody>{filtered.map((row) => <tr key={row.id}><td><strong className="mono">{row.reference}</strong></td><td><div className="route-cell"><span>{row.pickupLabel}</span><span>{row.deliveryLabel}</span></div></td><td>{row.client?.name ?? '—'}</td><td className="amount">EGP {Number(row.price).toFixed(0)}</td><td><select aria-label={`Change ${row.reference} status`} className="table-select" value={row.status} disabled={!editable || update.isPending} onChange={(event) => update.mutate({ id: row.id, changes: { status: event.target.value } })}>{statuses.map((status) => <option key={status} value={status}>{status.replaceAll('_', ' ')}</option>)}</select></td><td><select aria-label={`Assign ${row.reference} captain`} className="table-select captain-select" value={row.captain?.id ?? ''} disabled={!editable || update.isPending} onChange={(event) => update.mutate({ id: row.id, changes: { captainId: event.target.value } })}><option value="">Unassigned</option>{captains.filter((captain) => captain.status === 'ACTIVE').map((captain) => <option key={captain.user.id} value={captain.user.id}>{captain.user.name}</option>)}</select></td></tr>)}</tbody></table></div></section></>
}
const captainDocFields = [
  ['identity', 'National ID (front)', 'nationalIdDocument'],
  ['identity-back', 'National ID (back)', 'nationalIdBackDocument'],
  ['license', 'Driving license (front)', 'licenseDocument'],
  ['license-back', 'Driving license (back)', 'licenseBackDocument'],
  ['vehicle', 'Vehicle registration (front)', 'vehicleDocument'],
  ['vehicle-back', 'Vehicle registration (back)', 'vehicleBackDocument'],
  ['profile-photo', 'Profile photo', 'profilePhotoDocument'],
] as const

function useAuthBlobUrl(userId: string, docType: string, uploaded: boolean) {
  const [url, setUrl] = useState<string | null>(null)
  const [state, setState] = useState<'idle' | 'loading' | 'ready' | 'missing' | 'error'>('idle')
  useEffect(() => {
    if (!uploaded || !userId) { setState('missing'); return }
    const token = localStorage.getItem('wasalny-admin-token')
    if (!token) { setState('missing'); return }
    let objectUrl: string | null = null
    let cancelled = false
    setState('loading')
    fetch(`${import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1'}/admin/captains/${userId}/documents/${docType}`, { headers: { Authorization: `Bearer ${token}` } })
      .then(async (response) => {
        if (!response.ok) throw new Error('missing')
        const blob = await response.blob()
        if (cancelled) return
        objectUrl = URL.createObjectURL(blob)
        setUrl(objectUrl)
        setState('ready')
      })
      .catch(() => { if (!cancelled) setState('error') })
    return () => { cancelled = true; if (objectUrl) URL.revokeObjectURL(objectUrl) }
  }, [userId, docType, uploaded])
  return { url, state }
}

function DocumentTile({ userId, docType, label, uploaded }: { userId: string; docType: string; label: string; uploaded: boolean }) {
  const { url, state } = useAuthBlobUrl(userId, docType, uploaded)
  if (state === 'missing' || state === 'error') return <div className="doc-tile doc-missing"><span>{label}</span><small>Not uploaded</small></div>
  if (!url) return <div className="doc-tile doc-missing"><span>{label}</span><small>Loading…</small></div>
  return <figure className="doc-tile"><a href={url} target="_blank" rel="noreferrer"><img src={url} alt={label} /></a><figcaption>{label}</figcaption></figure>
}

function DetailItem({ label, value }: { label: string; value?: string | null }) {
  return <div className="detail-item"><span>{label}</span><strong>{value?.trim() ? value : '—'}</strong></div>
}

function CaptainReviewPage() {
  const { userId = '' } = useParams()
  const cache = useQueryClient()
  const editable = Boolean(localStorage.getItem('wasalny-admin-token'))
  const { data: captain, isLoading } = useQuery({
    queryKey: ['captain', userId],
    queryFn: () => api<Captain>(`/admin/captains/${userId}`),
    enabled: editable && Boolean(userId),
  })
  const [rejectOpen, setRejectOpen] = useState(false)
  const [reason, setReason] = useState('')
  const [message, setMessage] = useState('')
  const approve = useMutation({
    mutationFn: () => api(`/admin/captains/${userId}/approve`, { method: 'POST' }),
    onSuccess: () => { setMessage('Captain approved. The account is now active.'); cache.invalidateQueries({ queryKey: ['captain', userId] }); cache.invalidateQueries({ queryKey: ['captains'] }) },
    onError: (error) => setMessage(error.message),
  })
  const reject = useMutation({
    mutationFn: () => api(`/admin/captains/${userId}/reject`, { method: 'POST', body: JSON.stringify({ reason }) }),
    onSuccess: () => { setRejectOpen(false); setReason(''); setMessage('Application rejected. The captain can see the reason and resubmit documents.'); cache.invalidateQueries({ queryKey: ['captain', userId] }); cache.invalidateQueries({ queryKey: ['captains'] }) },
    onError: (error) => setMessage(error.message),
  })
  if (!editable) return <><Heading eyebrow="CAPTAIN REVIEW" title="Sign in required" description="Connect an administrator account from Settings to review applications." /></>
  if (isLoading || !captain) return <><Heading eyebrow="CAPTAIN REVIEW" title={isLoading ? 'Loading…' : 'Application not found'} description={isLoading ? 'Fetching the captain application.' : 'This captain application does not exist.'} /></>
  const missingDocs = captainDocFields.filter(([, , field]) => !captain[field as keyof Captain] || captain[field as keyof Captain] === 'PENDING_UPLOAD')
  const canApprove = missingDocs.length === 0 && captain.status !== 'ACTIVE'
  return <>
    <Heading
      eyebrow="CAPTAIN REVIEW"
      title={captain.user.name}
      description={`Application submitted ${new Date(captain.createdAt).toLocaleDateString()}`}
      action={<div className="heading-actions"><Status value={captain.status} />
        {captain.status === 'PENDING' || captain.status === 'REJECTED'
          ? <div className="inline-actions">
              <button className="button button-primary" disabled={!canApprove || approve.isPending} title={canApprove ? 'Approve captain' : 'Required documents are missing'} onClick={() => approve.mutate()}><Check size={15} /> Approve</button>
              <button className="button button-outline" disabled={reject.isPending} onClick={() => { setRejectOpen(true); setMessage('') }}><X size={15} /> Reject</button>
            </div>
          : null}
      </div>}
    />
    {message && <p className="form-message review-message">{message}</p>}
    {captain.status === 'REJECTED' && captain.rejectionReason && <div className="review-warning"><strong>Rejection reason:</strong> {captain.rejectionReason}</div>}
    <div className="review-layout">
      <section className="panel settings-panel">
        <div className="panel-heading"><div><div className="panel-kicker">APPLICANT</div><h2>Captain details</h2></div><span className="settings-icon"><ShieldCheck size={18} /></span></div>
        <div className="detail-grid">
          <DetailItem label="Full name" value={captain.user.name} />
          <DetailItem label="Email" value={captain.user.email} />
          <DetailItem label="Phone" value={captain.user.phone} />
          <DetailItem label="National ID" value={captain.nationalIdLast4 ? `•••• ${captain.nationalIdLast4}` : null} />
          <DetailItem label="Date of birth" value={captain.dateOfBirth ? new Date(captain.dateOfBirth).toLocaleDateString() : null} />
          <DetailItem label="Governorate" value={captain.governorate} />
          <DetailItem label="Driving license no." value={captain.licenseNumber} />
          <DetailItem label="Vehicle registration no." value={captain.vehicleRegistrationNumber} />
          <DetailItem label="Vehicle type" value={captain.vehicleType} />
          <DetailItem label="Plate" value={captain.vehiclePlate} />
          <DetailItem label="Make" value={captain.vehicleMake} />
          <DetailItem label="Model" value={captain.vehicleModel} />
          <DetailItem label="Color" value={captain.vehicleColor} />
          <DetailItem label="Wallet" value={captain.user.wallet ? `EGP ${Number(captain.user.wallet.balance).toFixed(0)}` : null} />
          <DetailItem label="Approved at" value={captain.approvedAt ? new Date(captain.approvedAt).toLocaleString() : null} />
          <DetailItem label="Reviewed at" value={captain.reviewedAt ? new Date(captain.reviewedAt).toLocaleString() : null} />
        </div>
      </section>
      <section className="panel settings-panel">
        <div className="panel-heading"><div><div className="panel-kicker">DOCUMENTS</div><h2>{missingDocs.length === 0 ? 'All 7 documents uploaded' : `${missingDocs.length} of 7 documents missing`}</h2></div></div>
        <div className="doc-grid">
          {captainDocFields.map(([docType, label, field]) => (
            <DocumentTile key={docType} userId={userId} docType={docType} label={label} uploaded={Boolean(captain[field as keyof Captain] && captain[field as keyof Captain] !== 'PENDING_UPLOAD')} />
          ))}
        </div>
      </section>
    </div>
    {rejectOpen && <div className="modal-scrim" role="dialog" aria-modal="true">
      <div className="modal-card">
        <div className="panel-heading"><div><div className="panel-kicker">REJECT APPLICATION</div><h2>Why is this application rejected?</h2></div><button className="icon-button" aria-label="Close" onClick={() => setRejectOpen(false)}><X size={16} /></button></div>
        <p className="settings-copy">The captain will see this reason and can update their documents and resubmit.</p>
        <textarea className="reason-input" required minLength={3} rows={4} placeholder="e.g. The driving license image is unreadable" value={reason} onChange={(event) => setReason(event.target.value)} />
        <div className="modal-actions">
          <button className="button button-outline" onClick={() => setRejectOpen(false)}>Cancel</button>
          <button className="button button-primary" disabled={reason.trim().length < 3 || reject.isPending} onClick={() => reject.mutate()}>{reject.isPending ? 'Rejecting…' : 'Reject application'}</button>
        </div>
      </div>
    </div>}
  </>
}

function CaptainsPage() {
  const [filter, setFilter] = useState('PENDING')
  const { data = [] } = useData<Captain[]>('captains', '/admin/captains', captainsDemo)
  const [search, setSearch] = useState('')
  const filtered = data.filter((row) => (filter === 'ALL' || row.status === filter) && `${row.user.name} ${row.user.email}`.toLowerCase().includes(search.toLowerCase()))
  const pendingCount = data.filter((row) => row.status === 'PENDING').length
  const filters = ['ALL', 'PENDING', 'ACTIVE', 'REJECTED', 'SUSPENDED']
  return <><Heading eyebrow="FLEET MANAGEMENT" title="Captains" description="Review applications and manage your delivery fleet." action={<span className="pending-chip">{pendingCount} applications to review</span>} /><section className="panel table-panel">
    <div className="table-toolbar"><label className="search-field"><Search size={16} /><input value={search} onChange={(event) => setSearch(event.target.value)} placeholder="Search captains" /></label><div className="filter-chips">{filters.map((value) => <button key={value} className={`chip ${filter === value ? 'chip-active' : ''}`} onClick={() => setFilter(value)}>{value === 'ALL' ? 'All' : value === 'ACTIVE' ? 'Approved' : value.charAt(0) + value.slice(1).toLowerCase()}</button>)}</div></div>
    <div className="table-scroll"><table><thead><tr><th>CAPTAIN</th><th>VEHICLE</th><th>NATIONAL ID</th><th>WALLET</th><th>STATUS</th><th>ACTIONS</th></tr></thead><tbody>{filtered.map((row) => <tr key={row.id}>
      <td><div className="person-cell"><span className="person-avatar">{row.user.name.split(' ').map((part) => part[0]).join('').slice(0, 2)}</span><span><strong>{row.user.name}</strong><small>{row.user.email}</small></span></div></td>
      <td>{row.vehicleType ?? '—'}<small>{row.vehiclePlate ?? '—'}</small></td>
      <td className="mono">{row.nationalIdLast4 ? `•••• ${row.nationalIdLast4}` : '—'}</td>
      <td className="amount">EGP {Number(row.user.wallet?.balance ?? 0).toFixed(0)}</td>
      <td><Status value={row.status} /></td>
      <td><Link className="text-link" to={`/captains/${row.user.id}`}><Eye size={14} /> Review</Link></td>
    </tr>)}</tbody></table></div>{filtered.length === 0 && <div className="empty-inline">No captains match this filter.</div>}</section></>
}
function ClientsPage() {
  const cache = useQueryClient()
  const { data = clientsDemo } = useData<Client[]>('clients', '/admin/clients', clientsDemo)
  const suspension = useMutation({ mutationFn: ({ id, suspended }: { id: string; suspended: boolean }) => api(`/admin/users/${id}/suspension`, { method: 'PATCH', body: JSON.stringify({ suspended }) }), onSuccess: () => cache.invalidateQueries({ queryKey: ['clients'] }) })
  const [search, setSearch] = useState('')
  const editable = Boolean(localStorage.getItem('wasalny-admin-token'))
  const rows = data.filter((row) => `${row.name} ${row.email}`.toLowerCase().includes(search.toLowerCase()))
  return <><Heading eyebrow="CUSTOMER DIRECTORY" title="Clients" description="Manage shipment senders and their account activity." /><section className="panel table-panel"><Toolbar value={search} setValue={setSearch} placeholder="Search clients" /><div className="table-scroll"><table><thead><tr><th>CLIENT</th><th>PHONE</th><th>ORDERS</th><th>ACCOUNT</th><th>ACTIONS</th></tr></thead><tbody>{rows.map((row) => <tr key={row.id}><td><div className="person-cell"><span className="person-avatar client-avatar">{row.name.slice(0, 2).toUpperCase()}</span><span><strong>{row.name}</strong><small>{row.email}</small></span></div></td><td>{row.phone ?? '—'}</td><td>{row._count?.clientOrders ?? 0}</td><td><Status value={row.suspendedAt ? 'SUSPENDED' : 'ACTIVE'} /></td><td><button className="text-action" disabled={!editable || suspension.isPending} onClick={() => suspension.mutate({ id: row.id, suspended: !row.suspendedAt })}>{row.suspendedAt ? 'Restore' : 'Suspend'}</button></td></tr>)}</tbody></table></div></section></>
}
function PricingPage() {
  const cache = useQueryClient()
  const defaults: Pricing = { basePrice: 30, pricePerKm: 8, commissionPercent: 10, minimumWalletBalance: 0 }
  const { data = defaults } = useData<Pricing>('pricing', '/admin/pricing', defaults)
  const [form, setForm] = useState<Pricing>(defaults)
  const [saved, setSaved] = useState(false)
  useEffect(() => setForm(data), [data])
  const mutation = useMutation({ mutationFn: () => api('/admin/pricing', { method: 'PATCH', body: JSON.stringify(form) }), onSuccess: () => { setSaved(true); cache.invalidateQueries({ queryKey: ['pricing'] }) } })
  return <><Heading eyebrow="COMMERCIAL RULES" title="Pricing & commission" description="Set transparent, automatic rates for ready-shipment deliveries." /><div className="settings-grid"><section className="panel settings-panel"><div className="panel-heading"><div><div className="panel-kicker">DELIVERY RATE</div><h2>Price calculation</h2></div><span className="settings-icon"><CircleDollarSign size={18} /></span></div><p className="settings-copy">Each order is priced from its pickup-to-dropoff distance. Clients see the final amount before confirming.</p><div className="field-grid"><label>Base price<span className="money-input"><span>EGP</span><input type="number" min="0" value={form.basePrice} onChange={(event) => setForm({ ...form, basePrice: Number(event.target.value) })} /></span></label><label>Price per kilometre<span className="money-input"><span>EGP</span><input type="number" min="0" value={form.pricePerKm} onChange={(event) => setForm({ ...form, pricePerKm: Number(event.target.value) })} /></span></label></div><div className="formula-note"><span>RATE FORMULA</span><strong>Base price + (distance × per km rate)</strong></div></section><section className="panel settings-panel"><div className="panel-heading"><div><div className="panel-kicker">CAPTAIN EARNINGS</div><h2>Commission & wallet</h2></div><span className="settings-icon orange-icon"><WalletCards size={18} /></span></div><p className="settings-copy">Commission is reserved from a captain's wallet when an order is accepted.</p><div className="field-grid"><label>Company commission<span className="money-input"><input type="number" min="0" max="100" value={form.commissionPercent} onChange={(event) => setForm({ ...form, commissionPercent: Number(event.target.value) })} /><span>%</span></span></label><label>Minimum wallet balance<span className="money-input"><span>EGP</span><input type="number" min="0" value={form.minimumWalletBalance} onChange={(event) => setForm({ ...form, minimumWalletBalance: Number(event.target.value) })} /></span></label></div><div className="formula-note"><span>DEFAULT COMMISSION</span><strong>{form.commissionPercent}% per delivery</strong></div></section><div className="settings-save"><span>{saved ? 'Pricing changes saved.' : 'Changes apply to new orders only.'}</span><button className="button button-primary" onClick={() => mutation.mutate()} disabled={mutation.isPending}><Check size={15} />{mutation.isPending ? 'Saving…' : 'Save changes'}</button></div></div></>
}
function WalletsPage() {
  const { data = [] } = useData<WalletRecord[]>('wallets', '/admin/wallets', [])
  const totalBalance = data.reduce((sum, row) => sum + Number(row.wallet?.balance ?? 0), 0)
  const transactions = data.flatMap((row) => row.walletTransactions.map((transaction) => ({ ...transaction, captain: row.name }))).sort((a, b) => b.createdAt.localeCompare(a.createdAt)).slice(0, 100)
  return <><Heading eyebrow="CAPTAIN FINANCES" title="Wallets & transactions" description="Monitor captain balances, commission reservations, and top-ups." /><section className="metric-grid report-metrics"><Metric label="Captain wallets" value={String(data.length)} change="Active accounts" icon={Bike} /><Metric label="Total available balance" value={`EGP ${totalBalance.toLocaleString()}`} change="Across all captains" icon={WalletCards} tone="blue" /></section><section className="panel table-panel"><div className="panel-heading table-heading"><div><div className="panel-kicker">WALLET LEDGER</div><h2>Recent transactions</h2></div></div><div className="table-scroll"><table><thead><tr><th>CAPTAIN</th><th>TYPE</th><th>DETAIL</th><th>DATE</th><th>AMOUNT</th></tr></thead><tbody>{transactions.map((transaction) => <tr key={transaction.id}><td>{transaction.captain}</td><td>{transaction.type.replaceAll('_', ' ')}</td><td>{transaction.note ?? '—'}</td><td>{new Date(transaction.createdAt).toLocaleString()}</td><td className="amount">EGP {Number(transaction.amount).toFixed(2)}</td></tr>)}</tbody></table></div>{transactions.length === 0 && <div className="empty-inline">No wallet transactions recorded yet.</div>}</section></>
}
function ReportsPage() {
  const { data = dashboardDemo } = useData<DashboardData>('dashboard', '/admin/dashboard', dashboardDemo)
  return <><Heading eyebrow="BUSINESS INTELLIGENCE" title="Reports" description="A clear read on completed deliveries and company earnings." action={<button className="button button-outline" onClick={() => window.print()}><Download size={15} /> Export report</button>} /><section className="metric-grid report-metrics"><Metric label="Completed deliveries" value={Number(data.completedOrders).toLocaleString()} change="10.4%" icon={Check} /><Metric label="Gross delivery value" value={`EGP ${Number(data.revenue).toLocaleString()}`} change="12.8%" icon={ArrowUpRight} tone="blue" /><Metric label="Company commission" value={`EGP ${Number(data.commission).toLocaleString()}`} change="12.8%" icon={CircleDollarSign} tone="orange" /></section><section className="panel activity-panel report-chart"><div className="panel-heading"><div><div className="panel-kicker">WEEKLY PERFORMANCE</div><h2>Delivery value</h2></div><span className="select-control">This week</span></div><div className="chart-wrap"><ResponsiveContainer width="100%" height="100%"><AreaChart data={weekly}><CartesianGrid vertical={false} stroke="#edf0ed" strokeDasharray="3 4" /><XAxis dataKey="day" tickLine={false} axisLine={false} /><YAxis tickLine={false} axisLine={false} /><Tooltip /><Area type="monotone" dataKey="revenue" stroke="#23886d" fill="#e9f4ed" /></AreaChart></ResponsiveContainer></div></section></>
}
function SettingsPage() {
  const token = localStorage.getItem('wasalny-admin-token')
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [message, setMessage] = useState('')
  const login = useMutation({ mutationFn: () => api<{ accessToken: string }>('/auth/login', { method: 'POST', body: JSON.stringify({ email, password }) }), onSuccess: (data) => { localStorage.setItem('wasalny-admin-token', data.accessToken); setMessage('Connected. Reload the page to load live data.') }, onError: (error) => setMessage(error.message) })
  return <><Heading eyebrow="WORKSPACE CONFIGURATION" title="Settings" description="Manage administrator access and service connectivity." /><div className="settings-grid"><section className="panel settings-panel"><div className="panel-heading"><div><div className="panel-kicker">ADMINISTRATOR ACCESS</div><h2>{token ? 'Connected session' : 'Connect your account'}</h2></div><span className="settings-icon"><ShieldCheck size={18} /></span></div>{token ? <><p className="settings-copy">This browser has an administrator access token.</p><button className="button button-outline" onClick={() => { localStorage.removeItem('wasalny-admin-token'); window.location.reload() }}>Sign out</button></> : <form className="access-form" onSubmit={(event) => { event.preventDefault(); login.mutate() }}><label>Admin email<input type="email" required value={email} onChange={(event) => setEmail(event.target.value)} placeholder="admin@wasalny.app" /></label><label>Password<input type="password" required value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Enter your password" /></label><button className="button button-primary" disabled={login.isPending}>{login.isPending ? 'Connecting…' : 'Connect administrator'}</button>{message && <p className="form-message">{message}</p>}</form>}</section><section className="panel settings-panel"><div className="panel-heading"><div><div className="panel-kicker">SERVICE STATUS</div><h2>Connected services</h2></div><span className="settings-icon"><Activity size={18} /></span></div><div className="service-list"><div><span><i /> API endpoint</span><code>{import.meta.env.VITE_API_URL ?? 'http://localhost:3000/api/v1'}</code></div><div><span><i /> Payment processing</span><small>Ready for Kashier integration</small></div><div><span><i /> Push notifications</span><small>Firebase credentials required</small></div></div></section></div></>
}
function LoginPage() { return <div className="login-shell"><span className="login-mark"><Boxes size={23} /></span><div className="eyebrow">WASALNY ORDERS</div><h1>Operations, in motion.</h1><p>Connect live order, captain, and pricing data from Settings.</p><Link to="/settings" className="button button-primary">Go to settings <ArrowRight size={16} /></Link></div> }

export default function Dashboard() {
  return <Routes><Route element={<Frame />}><Route index element={<Overview />} /><Route path="orders" element={<OrdersPage />} /><Route path="captains" element={<CaptainsPage />} /><Route path="captains/:userId" element={<CaptainReviewPage />} /><Route path="clients" element={<ClientsPage />} /><Route path="wallets" element={<WalletsPage />} /><Route path="reports" element={<ReportsPage />} /><Route path="pricing" element={<PricingPage />} /><Route path="settings" element={<SettingsPage />} /><Route path="*" element={<LoginPage />} /></Route></Routes>
}