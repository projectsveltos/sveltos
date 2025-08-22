/*
 * The below code is an anonymous function used as a callback for a defined subscription.
 * The code enhances the copy to clipboard functionality and removes any $ sign from
 * code snippets to achieve better user experience.
 */

document$.subscribe(function() {

  const copyButton = document.querySelectorAll('.md-clipboard');

  copyButton.forEach(function(button) {

    const codeElement = button.closest('.highlight, pre').querySelector('code');

    if (codeElement) {

      const actualText = codeElement.textContent;

      button.addEventListener('click', function() {

        const modifiedText = actualText.replace(/^((\$)\s*)/gm, '');

        navigator.clipboard.writeText(modifiedText)
          .catch(() => {
          });
      });
    }
  });
});