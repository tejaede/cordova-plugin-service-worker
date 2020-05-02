try { 
    cordovaCallback(%@, %@, %@); 
} catch (e) { 
    console.error('Failed to call cordova callback');
}
''; //Prevents WKWebView evaluateJavascript from throwing warning