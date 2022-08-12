Feature('Seahub');

Before(({ I, login }) => { 
    login('admin');
  });

Scenario('Test about', ({ I }) => {
    I.amOnPage('/');  
    I.click('About');
    I.waitForText(process.env.SEAFILE_SERVER_VERSION);
});

Scenario('Test config', ({ I }) => {
  I.amOnPage('/sys/web-settings/')
  I.seeInField('div.mb-4:nth-child(2) > div:nth-child(2) > div:nth-child(2) > input:nth-child(1)', 
    'http://' + process.env.URL + ':' + process.env.PORT);
  I.seeInField('div.mb-4:nth-child(2) > div:nth-child(3) > div:nth-child(2) > input:nth-child(1)', 
    'http://' + process.env.URL + ':' + process.env.PORT + '/seafhttp');
});

Scenario('Test new library', ({ I }) => {
  I.amOnPage('/');
  I.click('New Library');
  I.waitForElement('#repoName');
  
  const library = 'library' + new Date().getTime();
  I.fillField('#repoName', library);
  I.click('Submit');
  I.see(library, 'a');
});
