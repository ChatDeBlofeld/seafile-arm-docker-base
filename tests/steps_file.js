// in this file you can append custom step methods to 'I' object

module.exports = function() {
  return actor({

    // Define custom steps here, use 'this' to access default methods of I.
    // It is recommended to place a general 'login' function here.

    // Login funcion
    loginAdmin() {
      this.amOnPage('/');
      this.fillField('login', process.env.SEAFILE_ADMIN_EMAIL);
      this.fillField('password', process.env.SEAFILE_ADMIN_PASSWORD);
      this.click('.submit');
    }



  });
}
