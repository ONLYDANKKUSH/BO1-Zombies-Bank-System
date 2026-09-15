#include maps\_utility;
#include maps\_zombiemode_utility;

main()
{
    // Register the persistent storage Dvar if it doesn't exist yet
    if( getDvar( "scr_bank_storage" ) == "" )
    {
        setDvar( "scr_bank_storage", "" );
    }

    // Initialize the mod framework hooks
    level thread on_player_connect();
    level thread auto_deposit_on_end_game();
    
    // Start the global chat interception listener
    level thread chat_command_listener();
}

on_player_connect()
{
    for(;;)
    {
        level waittill( "connecting", player );
        
        // Ensure player bank profile exists in persistent storage
        guid = player getGuid();
        balance = get_persistent_balance( guid );
        
        // If not found in our Dvar storage string, initialize it to 0
        if( !isDefined( balance ) )
        {
            set_persistent_balance( guid, 0 );
        }
    }
}

chat_command_listener()
{
    level endon( "end_game" );

    for(;;)
    {
        level waittill( "say", message, player, is_hidden );
        
        if( !isDefined( player ) || !isDefined( message ) )
            continue;

        args = strtok( message, " " );
        if( args.size == 0 )
            continue;

        command = args[0];

        if( command == ".w" || command == ".with" || command == ".withdraw" )
        {
            if( args.size < 2 )
            {
                player iprintln( "Usage: .w <number|all>" );
                continue;
            }
            player thread withdraw_logic( args[1] );
        }
        else if( command == ".d" || command == ".dep" || command == ".deposit" )
        {
            if( args.size < 2 )
            {
                player iprintln( "Usage: .d <number|all>" );
                continue;
            }
            player thread deposit_logic( args[1] );
        }
        else if( command == ".b" || command == ".bal" || command == ".balance" )
        {
            player thread balance_logic();
        }
    }
}

balance_logic()
{
    guid = self getGuid();
    current_balance = get_persistent_balance( guid );
    self iprintln( "Current balance: " + current_balance + " | Max: 1000000" );
}

withdraw_logic( arg_val )
{
    guid = self getGuid();
    current_balance = get_persistent_balance( guid );

    if( current_balance <= 0 )
    {
        self iprintln( "Withdraw failed: empty bank score" );
        return;
    }

    if( self.score >= 1000000 )
    {
        self iprintln( "Withdraw failed: Max score is 1000000" );
        return;
    }

    amount = 0;
    if( arg_val == "all" )
    {
        amount = current_balance;
    }
    else
    {
        if( !is_valid_integer( arg_val ) )
        {
            self iprintln( "Withdraw failed: Value must be 1000 or greater" );
            return;
        }

        amount = int( arg_val );
        if( amount < 1000 )
        {
            self iprintln( "Withdraw failed: Value must be 1000 or greater" );
            return;
        }
    }

    if( amount > current_balance )
    {
        amount = current_balance;
    }

    if( ( self.score + amount ) > 1000000 )
    {
        amount = 1000000 - self.score;
    }

    amount = floor( amount / 1000 ) * 1000;

    if( amount <= 0 )
        return;

    set_persistent_balance( guid, current_balance - amount );
    self.score += amount;

    self iprintln( "Successfully withdrew: " + amount );
}

deposit_logic( arg_val )
{
    guid = self getGuid();
    current_balance = get_persistent_balance( guid );

    if( current_balance >= 1000000 )
    {
        self iprintln( "Deposit failed: Max bank is 1000000" );
        return;
    }

    if( self.score < 1000 )
    {
        self iprintln( "Deposit failed: Not enough points" );
        return;
    }

    amount = 0;
    if( arg_val == "all" )
    {
        amount = self.score;
    }
    else
    {
        if( !is_valid_integer( arg_val ) )
        {
            self iprintln( "Deposit failed: Value must be 1000 or greater" );
            return;
        }

        amount = int( arg_val );
        if( amount < 1000 )
        {
            self iprintln( "Deposit failed: Value must be 1000 or greater" );
            return;
        }
    }

    if( amount > self.score )
    {
        amount = self.score;
    }

    if( ( current_balance + amount ) > 1000000 )
    {
        amount = 1000000 - current_balance;
    }

    amount = floor( amount / 1000 ) * 1000;

    if( amount <= 0 )
        return;

    set_persistent_balance( guid, current_balance + amount );
    self.score -= amount;

    self iprintln( "Successfully deposited: " + amount );
}

auto_deposit_on_end_game()
{
    level waittill( "end_game" );

    players = get_players();
    for( i = 0; i < players.size; i++ )
    {
        player = players[i];
        
        if( !isDefined( player ) || player.score < 1000 )
            continue;

        guid = player getGuid();
        current_balance = get_persistent_balance( guid );
        if( current_balance >= 1000000 )
            continue;

        amount_to_deposit = player.score;
        if( ( current_balance + amount_to_deposit ) > 1000000 )
        {
            amount_to_deposit = 1000000 - current_balance;
        }

        amount_to_deposit = floor( amount_to_deposit / 1000 ) * 1000;

        if( amount_to_deposit <= 0 )
            continue;

        set_persistent_balance( guid, current_balance + amount_to_deposit );
        player.score -= amount_to_deposit;

        player iprintln( "Game Over: Auto-deposited " + amount_to_deposit + " points!" );
    }
}

/* ==========================================
   ENGINE STORAGE PERSISTENCE FUNCTIONS
   ========================================== */

get_persistent_balance( player_guid )
{
    raw_string = getDvar( "scr_bank_storage" );
    if( raw_string == "" )
    {
        return undefined;
    }

    // Split the global string into single player profile data packets
    entries = strtok( raw_string, ";" );
    for( i = 0; i < entries.size; i++ )
    {
        data = strtok( entries[i], ":" );
        if( data.size == 2 && data[0] == player_guid )
        {
            return int( data[1] );
        }
    }
    return undefined;
}

set_persistent_balance( player_guid, new_val )
{
    raw_string = getDvar( "scr_bank_storage" );
    new_string = "";
    found = false;

    if( raw_string != "" )
    {
        entries = strtok( raw_string, ";" );
        for( i = 0; i < entries.size; i++ )
        {
            data = strtok( entries[i], ":" );
            if( data.size == 2 )
            {
                if( data[0] == player_guid )
                {
                    new_string += player_guid + ":" + new_val + ";";
                    found = true;
                }
                else
                {
                    new_string += entries[i] + ";";
                }
            }
        }
    }

    if( !found )
    {
        new_string += player_guid + ":" + new_val + ";";
    }

    setDvar( "scr_bank_storage", new_string );
}

is_valid_integer( str )
{
    list_num = "0123456789";
    for( i = 0; i < str.size; i++ )
    {
        match = false;
        for( j = 0; j < list_num.size; j++ )
        {
            if( str[i] == list_num[j] )
            {
                match = true;
                break;
            }
        }
        if( !match )
            return false;
    }
    return true;
}
