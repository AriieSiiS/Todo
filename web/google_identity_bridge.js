window.todoGoogleBridge = {
  requestAccessToken(clientId, scope) {
    return new Promise((resolve, reject) => {
      if (!window.google || !window.google.accounts || !window.google.accounts.oauth2) {
        reject(new Error('Google Identity Services no esta disponible.'));
        return;
      }

      const tokenClient = window.google.accounts.oauth2.initTokenClient({
        client_id: clientId,
        scope,
        callback: (response) => {
          if (response && response.error) {
            reject(new Error(response.error));
            return;
          }
          resolve(response);
        },
      });

      tokenClient.requestAccessToken({ prompt: 'consent' });
    });
  },

  revoke(token) {
    return new Promise((resolve) => {
      if (!window.google || !window.google.accounts || !window.google.accounts.oauth2) {
        resolve();
        return;
      }
      window.google.accounts.oauth2.revoke(token, () => resolve());
    });
  },
};
