const windows = new Map();
const period = 15 * 60 * 1000;
const networkLimit = 80;
const accountLimit = 10;

const cleanup = setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of windows) {
    if (entry.expires <= now) windows.delete(key);
  }
}, period);
cleanup.unref();

function bucket(key) {
  const now = Date.now();
  const previous = windows.get(key);
  if (previous && previous.expires > now) return previous;
  const entry = { failures: 0, expires: now + period };
  windows.set(key, entry);
  return entry;
}

export function canAttempt(address, username) {
  if (windows.size >= 10000) return false;
  const network = bucket('network:' + address);
  if (network.failures >= networkLimit) return false;
  const account = bucket('account:' + username.toLowerCase());
  if (account.failures >= accountLimit) return false;
  // Count in-flight attempts too, before login awaits a database connection.
  network.failures++;
  account.failures++;
  return () => {
    network.failures = Math.max(0, network.failures - 1);
    account.failures = 0;
  };
}
