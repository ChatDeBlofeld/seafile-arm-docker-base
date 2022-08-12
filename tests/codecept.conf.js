exports.config = {
  tests: './*_test.js',
  output: './output',
  helpers: {
    WebDriver: {
      browser: 'chrome',
      host: 'selenium-chrome',
      url: 'http://' + process.env.URL + ':' + process.env.PORT,
      show: false
    }
  },
  include: {
    I: './steps_file.js'
  },
  bootstrap: null,
  mocha: {},
  name: 'tests',

  plugins: {
    autoLogin: {
      enabled: true,
      saveToFile: true,
      inject: 'login',
      users: {
        admin: {
          // loginAdmin function is defined in `steps_file.js`
          login: (I) => I.loginAdmin(),
          // if we see `Admin` on page, we assume we are logged in
          check: (I) => {
             I.amOnPage('/');
             I.seeElement('.avatar');
          }
        }
      }
    }
    
  }
}