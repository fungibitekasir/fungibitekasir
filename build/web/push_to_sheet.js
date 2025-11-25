async function pushToSheetJS(data) {
  const url = "https://script.google.com/macros/s/AKfycbyRkEa1wv7Thp_9L0P7USgajLd2SMAPHyMlMlpqK3_98u7fOmY7w0eCMn8UMDrflol4/exec"; // ganti sesuai URL Web App

  try {
    const response = await fetch(url, {
      method: "POST",
      mode: "cors",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data),
    });

    const result = await response.json();
    console.log("Web JS: berhasil push data", result);
    return result;
  } catch (err) {
    console.error("Web JS: gagal push data", err);
    throw err;
  }
}
