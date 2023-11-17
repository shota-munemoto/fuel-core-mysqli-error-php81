<?php

namespace Fuel\Tasks;

class UseMysqli
{
	public static function run()
	{
		\Cli::write('use mysqli');
		\DB::query('select * from `users` where `id` > 1');
		\Cli::write('done');
	}
}
