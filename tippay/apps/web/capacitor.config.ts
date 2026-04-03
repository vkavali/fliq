import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'co.in.fliq.app',
  appName: 'Fliq',
  webDir: 'public',
  android: {
    backgroundColor: '#6C5CE7',
    allowMixedContent: false
  },
  ios: {
    backgroundColor: '#6C5CE7',
    contentInset: 'automatic',
    scheme: 'Fliq'
  }
};

export default config;
