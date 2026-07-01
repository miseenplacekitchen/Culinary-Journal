// tcj-recipe-photo-upload.js — upload dish/recipe photos to Supabase storage (dashboard + Dish Index editor)
(function() {
  async function tcjUploadRecipeImage(fileOrDataUrl) {
    var sess = typeof window.getSession === 'function' ? window.getSession() : null;
    if (!sess || !sess.access_token) throw new Error('Sign in required to upload photos.');
    var userId = (sess.user && sess.user.id) || sess.id;
    if (!userId) throw new Error('User session invalid.');

    var blob;
    if (typeof fileOrDataUrl === 'string') {
      if (!fileOrDataUrl.startsWith('data:')) return fileOrDataUrl;
      blob = await fetch(fileOrDataUrl).then(function(r) { return r.blob(); });
    } else if (fileOrDataUrl && fileOrDataUrl instanceof Blob) {
      blob = fileOrDataUrl;
    } else {
      throw new Error('No image to upload.');
    }

    var ext = (blob.type && blob.type.indexOf('png') >= 0) ? 'png' : 'jpg';
    var path = userId + '/' + Date.now() + '-dish-index.' + ext;
    var url = window.SUPA_URL + '/storage/v1/object/recipe-images/' + path;
    var headers = typeof window.getAuthHeaders === 'function'
      ? window.getAuthHeaders()
      : { apikey: window.SUPA_KEY, Authorization: 'Bearer ' + sess.access_token };

    var res = await fetch(url, {
      method: 'POST',
      headers: Object.assign({}, headers, {
        'Content-Type': blob.type || 'image/jpeg',
        'x-upsert': 'true'
      }),
      body: blob
    });
    if (!res.ok) {
      var msg = 'Upload failed (' + res.status + ')';
      try {
        var err = await res.json();
        if (err && err.message) msg = err.message;
      } catch (_) {}
      throw new Error(msg);
    }
    return window.SUPA_URL + '/storage/v1/object/public/recipe-images/' + path;
  }

  window.tcjUploadRecipeImage = tcjUploadRecipeImage;
})();
