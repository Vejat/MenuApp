window.menuAppEnablePush = async token => {
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) return false;
  const permission = await Notification.requestPermission();
  if (permission !== 'granted') return false;
  const keyResponse = await fetch('/push/key');
  if (!keyResponse.ok) return false;
  const { publicKey } = await keyResponse.json();
  const registration = await navigator.serviceWorker.register('/push-worker.js');
  const decode = value => {
    const base64 = value.replace(/-/g, '+').replace(/_/g, '/');
    return Uint8Array.from(atob(base64 + '='.repeat((4 - base64.length % 4) % 4)), c => c.charCodeAt(0));
  };
  let subscription = await registration.pushManager.getSubscription();
  if (!subscription) subscription = await registration.pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: decode(publicKey) });
  const response = await fetch('/push/subscribe', { method: 'POST', headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' }, body: JSON.stringify({ subscription }) });
  return response.ok;
};
