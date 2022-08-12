Feature('Seafile');

Before(({ I, login }) => { 
    login('admin');
  });

Scenario('Test file download', ({ I }) => {
    I.amOnPage('/');
    I.see('My Library');
    I.click('My Library');
    // I.see('seafile-tutorial.doc');
    I.waitForText('seafile-tutorial.doc');
    I.click('.name > a:nth-child(1)');
    I.waitForText('Download');
    I.click('Download');
    I.waitForText("Je ne sais pas");
});
