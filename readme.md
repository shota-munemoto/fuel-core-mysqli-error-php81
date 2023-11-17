# About fuel core fails database migration with MySQLi in PHP 8.1 or later

## To reproduce the error occuring

Build a sample environment.

```sh
docker compose build
docker compose up -d
docker compose run app bash
```

I created a project with `oil create app`, edited `app/fuel/app/config/development/db.php` to use mysqli and created a migration file with `oil generate` command in docker containers above.  
It's a very simple environment.

```sh
php oil generate migration create_users name:text email:string[50] password:string[125]
```

Then run `php oil r migrate`.

The error occurs.

```txt
root@a6382a504ab1:/var/www/html/app# php oil r migrate
Uncaught exception mysqli_sql_exception: 1146 - Table 'test.migration' doesn't exist in /var/www/html/app/fuel/core/classes/database/mysqli/connection.php on line 299
Callstack:
#0 /var/www/html/app/fuel/core/classes/database/mysqli/connection.php(299): mysqli->query('SELECT * FROM `...', 0)
#1 /var/www/html/app/fuel/core/classes/database/schema.php(177): Fuel\Core\Database_MySQLi_Connection->query(1, 'SELECT * FROM `...', false)
#2 [internal function]: Fuel\Core\Database_Schema->table_exists('migration')
#3 /var/www/html/app/fuel/core/classes/database/connection.php(346): call_user_func_array(Array, Array)
#4 /var/www/html/app/fuel/core/classes/dbutil.php(387): Fuel\Core\Database_Connection->schema('table_exists', Array)#5 /var/www/html/app/fuel/core/classes/migrate.php(652): Fuel\Core\DBUtil::table_exists('migration')
#6 /var/www/html/app/fuel/core/classes/migrate.php(75): Fuel\Core\Migrate::table_version_check()
#7 [internal function]: Fuel\Core\Migrate::_init()
#8 /var/www/html/app/fuel/core/classes/autoloader.php(377): call_user_func('Migrate::_init')
#9 /var/www/html/app/fuel/core/classes/autoloader.php(249): Fuel\Core\Autoloader::init_class('Migrate')
#10 /var/www/html/app/fuel/core/tasks/migrate.php(283): Fuel\Core\Autoloader::load('Migrate')
#11 /var/www/html/app/fuel/core/tasks/migrate.php(197): Fuel\Tasks\Migrate::_run('default', 'app')
#12 /var/www/html/app/fuel/core/base56.php(37): Fuel\Tasks\Migrate->__call('_run', Array)
#13 /var/www/html/app/fuel/packages/oil/classes/refine.php(106): call_fuel_func_array(Array, Array)
#14 [internal function]: Oil\Refine::run('\\Fuel\\Tasks\\Mig...', Array)
#15 /var/www/html/app/fuel/packages/oil/classes/command.php(124): call_user_func('Oil\\Refine::run', 'migrate', Array)
#16 /var/www/html/app/oil(68): Oil\Command::init(Array)
#17 {main}
```

To see what query occurred `Uncaught exception mysqli_sql_exception: 1146 - Table 'test.migration' doesn't exist`, I added `\Cli::write($sql);` before the line `fuel/core/classes/database/mysqli/connection.php(299)`.

Then I found that this query that checks table `migration` exists occurred the error.

```sql
SELECT * FROM `migration` LIMIT 1
```

In PHP 8.1 or later, MySQLi with a query that runs `SELECT` on **non existent table** fails and throws an exception.  
In PHP 8.0 or older, MySQLi returns false in such a case.

So this error occurred when the first time of migration.  
If you already created `migration` table when using PHP 8.0 or older one, you cannot see this error.  
But you can see this error when running tests that re-creating database and tables with MySQLi connections.

Another reference:  
mysqli_query returns fatal error when table in query doesn't exist · Issue #8148 · php/php-src
https://github.com/php/php-src/issues/8148

```txt
root@45ca52faecfc:/var/www/html/app# php oil r migrate
SELECT * FROM `migration` LIMIT 1
Uncaught exception mysqli_sql_exception: 1146 - Table 'test.migration' doesn't exist in /var/www/html/app/fuel/core/classes/database/mysqli/connection.php on line 301
Callstack:
#0 /var/www/html/app/fuel/core/classes/database/mysqli/connection.php(301): mysqli->query('SELECT * FROM `...', 0)
#1 /var/www/html/app/fuel/core/classes/database/schema.php(177): Fuel\Core\Database_MySQLi_Connection->query(1, 'SELECT * FROM `...', false)
#2 [internal function]: Fuel\Core\Database_Schema->table_exists('migration')
#3 /var/www/html/app/fuel/core/classes/database/connection.php(346): call_user_func_array(Array, Array)
#4 /var/www/html/app/fuel/core/classes/dbutil.php(387): Fuel\Core\Database_Connection->schema('table_exists', Array)
#5 /var/www/html/app/fuel/core/classes/migrate.php(652): Fuel\Core\DBUtil::table_exists('migration')
#6 /var/www/html/app/fuel/core/classes/migrate.php(75): Fuel\Core\Migrate::table_version_check()
#7 [internal function]: Fuel\Core\Migrate::_init()
...(omit)
```

After editing fuel/core/classes/database/mysqli/connection.php

```
		// Make error reporting compatible with the behavior prior to PHP 8.1
		mysqli_report(MYSQLI_REPORT_OFF);
```

The migration succeeded.

```txt
root@a6382a504ab1:/var/www/html/app# php oil r migrate
SELECT * FROM `migration` LIMIT 1
Performed migrations for app:default:
001_create_users
```

So **first time migration** fails when using MySQLi connection in PHP 8.1 or later.

This pull request makes the error reporting mode to be compatible with pre-PHP 8.0 behavior.

[[php81] make MySQLi error reporting compatible with before PHP 8.1 by shota-munemoto · Pull Request #2199 · fuel/core](https://github.com/fuel/core/pull/2199)

PHP: Backward Incompatible Changes - Manual
https://www.php.net/manual/en/migration81.incompatible.php

> The default error handling mode has been changed from "silent" to "exceptions" See the MySQLi reporting mode page for more details on what this entails, and how to explicitly set this attribute. To restore the previous behaviour use: mysqli_report(MYSQLI_REPORT_OFF);
