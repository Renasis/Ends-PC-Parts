// Shrinks an image and returns a small base64 data URL, so it fits
// comfortably in the Realtime Database and loads fast in the app.

function resizeImage(src, { maxSize = 800, type = 'image/jpeg', quality = 0.8 } = {}) {
  return new Promise((resolve, reject) => {
    const img = new Image();

    img.onload = () => {
      const scale = Math.min(1, maxSize / Math.max(img.width, img.height));
      const width = Math.max(1, Math.round(img.width * scale));
      const height = Math.max(1, Math.round(img.height * scale));

      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      if (type === 'image/jpeg') {
        ctx.fillStyle = '#ffffff'; // JPEG has no transparency
        ctx.fillRect(0, 0, width, height);
      }
      ctx.drawImage(img, 0, 0, width, height);
      resolve(canvas.toDataURL(type, quality));
    };

    img.onerror = () => reject(new Error('That file could not be read as an image.'));
    img.src = src;
  });
}

// Reads an image file and returns it resized as a data URL.
export function fileToDataUrl(file, options) {
  if (!file || !file.type.startsWith('image/')) {
    return Promise.reject(new Error('Please choose an image file.'));
  }
  const objectUrl = URL.createObjectURL(file);
  return resizeImage(objectUrl, options).finally(() => URL.revokeObjectURL(objectUrl));
}

// Resizes an image that is already a data URL (used to convert old products).
export function resizeDataUrl(dataUrl, options) {
  return resizeImage(dataUrl, options);
}