/*
 * When the copy button is clicked, the script temporary modifies the displayed text.
 * The leading characters '$' or '$ ' are removed from the code snippets.
 * After 10ms delay, the original text is restored.
 */

document$.subscribe(function() {

  const copyButton = document.querySelectorAll('.md-clipboard');

  copyButton.forEach(function(button) {

    const codeElement = button.closest('.highlight, pre').querySelector('code');

    if (codeElement) {

      let actualText = codeElement.textContent;

      button.addEventListener('click', function() {

        const modifiedText = actualText.replace(/^((\$)\s*)/gm, '');

        codeElement.textContent = modifiedText;

        setTimeout(() => {
          codeElement.textContent = actualText;
        }, 10);

      });
    }
  });
});
