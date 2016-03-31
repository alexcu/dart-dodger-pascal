//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//
//								--DART DODGER v4.0--
//						  Written By Alex Cummaudo, 1744070
//				 For HIT1301 - Algorithmic Problem Solving Portfolio
//
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

program DartDodger;
uses SwinGame, sgTypes, SysUtils, Math;

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//								CONSTANTS AND TYPES
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

const
	BALLOON_YPOS = 400;
	MAX_DARTS = 30 - 1;
	BALLOON_YPOS_ADD = 20;
  HIGH_SCORE_NAME = 'ddhs.txt';

type
	Direction = (left, right);

	BalloonPosition = (normal, offLeft, offRight);
	BalloonData = Record
		xPos : Integer;
		status : BalloonPosition;
	end;

	DartData = Record
		xPos : Integer;
		yPos : Integer;
		onScreen : Boolean;
	end;

	CloudData = Record
		xPos : Integer;
		dir : Direction;
		onScreen : Boolean;
	end;

	HealthData = Record
		xPos : Integer;
		yPos : Integer;
		onScreen : Boolean;
		dyingTimer : Timer;
	end;

	ControlData = Record
		playerScore : Integer;
		playerTempScore : Integer;
		highScore : Integer;
		playerLives : Integer;
		dartLimit : Integer;
		gameSpeed : Integer;
		background_yPos : Integer;
		menu : Boolean;
		scoreTimer : Timer;
		chanceTimer : Timer;
		resetGame : Boolean;
	end;

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//							MISC. FUNCTIONS/PROCEDURES
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//-----------------------------------------------------------------------------
// RandomRange Function
// DESCRIPTION:	Function returns an integer within the inclusive range
//-----------------------------------------------------------------------------

function RandomRange(min, max : Integer): Integer ;
begin
	result := Round(min + (max-min)*Rnd());
end;

//-----------------------------------------------------------------------------
// NewHighScoreFile
// DESCRIPTION: Creates a new high score file if not there or corrupted.
//-----------------------------------------------------------------------------

procedure NewHighScoreFile(corrupted : Boolean);
var
	HighScoreFile : Text;
begin
	// Check if HS file doesn't exist
	if (not FileExists(FilenameToResource(HIGH_SCORE_NAME, BundleResource))) or (corrupted) then
	begin
		// Make a file
		FileCreate(FilenameToResource(HIGH_SCORE_NAME, BundleResource));
		Assign(HighScoreFile, FilenameToResource(HIGH_SCORE_NAME, BundleResource));
		Rewrite(HighScoreFile);
		// Add a zero score
		Write(HighScoreFile, '0');
		CloseFile(HighScoreFile);
	end;
end;

//-----------------------------------------------------------------------------
// ReadHighScore
// DESCRIPTION: Retrieves the high score from the high score file
//				Will create a new high score file if not there or corrupted.
//-----------------------------------------------------------------------------

function ReadHighScore(): Integer ;
var
	HighScoreFile : Text;
	HighScoreStr : String;
begin
	// Create a new high score file if non-existant
	NewHighScoreFile(false);

	// Open the HS File for reading
	Assign(HighScoreFile, FilenameToResource(HIGH_SCORE_NAME, BundleResource));
	Reset(HighScoreFile);

	// Read previous HS and close
	Read(HighScoreFile, HighScoreStr);
	CloseFile(HighScoreFile);

	// If the HS value was not integer (i.e. corrupted HS file)
	if (not TryStrToInt(HighScoreStr, result)) then
	begin
		// Delete corrupted HS file
		DeleteFile(FilenameToResource(HIGH_SCORE_NAME, BundleResource));
		// Create a new high score file
		NewHighScoreFile(true);
	end

	// Else it was an an integer
	else
	begin
		result := StrToInt(HighScoreStr);
	end;
end;

//-----------------------------------------------------------------------------
// WriteHighScore
// DESCRIPTION: Writes the high score to file.
//				Will create a new high score file if not there or corrupted.
//-----------------------------------------------------------------------------

procedure WriteHighScore(const playerScore: Integer);
var
	HighScoreFile : Text;
begin
	// Create a new high score file if non-existant
	NewHighScoreFile(false);

	// Check if current score beats high score
	Assign(HighScoreFile, FilenameToResource(HIGH_SCORE_NAME, BundleResource));
	Rewrite(HighScoreFile);
	// Add the new high score
	Write(HighScoreFile, IntToStr(playerScore));
	CloseFile(HighScoreFile);
end;

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//								BEGIN SETUP
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//-----------------------------------------------------------------------------
// LoadResources
// DESCRIPTION:	Procedure loads all game resources into memory
//-----------------------------------------------------------------------------

procedure LoadResources();
begin
	//Load Bitmaps
	LoadBitmapNamed('background', 'background.png');
	LoadBitmapNamed('balloon', 'balloon.png');
	LoadBitmapNamed('dart', 'dart.png');
	LoadBitmapNamed('cloud', 'cloud.png');
	LoadBitmapNamed('health', 'health.png');
	LoadBitmapNamed('icon', 'icon.png');

	//Load Music/Sound
	LoadMusicNamed('song', 'mainsong2.ogg');
	LoadSoundEffectNamed('menu', 'menu.ogg');
	LoadSoundEffectNamed('die-1', 'die-1.ogg');
	LoadSoundEffectNamed('die-2', 'die-2.ogg');
	LoadSoundEffectNamed('loselife-1', 'loselife-1.ogg');
	LoadSoundEffectNamed('loselife-2', 'loselife-2.ogg');
	LoadSoundEffectNamed('loselife-3', 'loselife-3.ogg');
	LoadSoundEffectNamed('slidepast-1', 'slidepast-1.ogg');
	LoadSoundEffectNamed('slidepast-2', 'slidepast-2.ogg');
	LoadSoundEffectNamed('slidepast-3', 'slidepast-3.ogg');
	LoadSoundEffectNamed('health', 'newround.ogg');

	//Load Fonts
	LoadFontNamed('pixel','BitxMap.ttf', 20);
	LoadFontNamed('menu','edunline.ttf', 65);
end;

//============================================================================
// Initialise
// DESCRIPTION:	Procedure intialises many pass by reference values
//				Can also be used to reset the game
//============================================================================

procedure Initialise(	var balloon : BalloonData;
						var darts : array of DartData;
						var cloud : CloudData;
						var health : HealthData;
						var ctrl : ControlData);
var
	i : Integer;
begin
	// A new, initialised game has a colour of Blue
	ClearScreen(ColorBlue);

	// Start to play annoying music infinitley
	PlayMusic('song', -1);

	// Balloon Variable Initialisation
	// Set the balloon x pos and status
	balloon.xPos := Round(	ScreenWidth() / 2 -
							BitmapWidth(BitmapNamed('balloon')) / 2);
	balloon.status := normal;

	// Dart Variable Initialisation
	for i := Low(darts) to High(darts) do
		darts[i].onScreen := false;

	// Cloud Variable Initialisation
	cloud.onScreen := false;

	// Health Variable Initialisation
	health.onScreen := false;
	health.xPos := RandomRange(	5,
								ScreenWidth() - 15);
	health.yPos := RandomRange(	-BitmapHeight(BitmapNamed('dart')),
								-ScreenHeight());
	health.dyingTimer := CreateTimer();

	// Controller Variable Initialisation
	ctrl.playerScore := 0;
	ctrl.playerTempScore := 0;
	ctrl.highScore := ReadHighScore();
	ctrl.playerLives := 3;
	ctrl.dartLimit := MAX_DARTS;
	ctrl.gameSpeed := 3;
	ctrl.background_yPos := ScreenHeight() -
							BitmapHeight(BitmapNamed('background'));
	ctrl.menu := true;
	ctrl.resetGame := false;
	ctrl.scoreTimer := CreateTimer();
	StartTimer(ctrl.scoreTimer);
	ctrl.chanceTimer := CreateTimer();
	StartTimer(ctrl.chanceTimer);
end;

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//							UPDATE PROCEDURES
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//-----------------------------------------------------------------------------
// LoopDart
// DESCRIPTION:	Procedure loops a given dart back to a random x
//				and y position above the screen
//-----------------------------------------------------------------------------

procedure LoopDart(var dart : DartData);
begin
	dart.xPos := RandomRange(	5,
								ScreenWidth() - 15);
	dart.yPos := RandomRange(	-BitmapHeight(BitmapNamed('dart')),
								-ScreenHeight());
	dart.onScreen := false;
end;

//-----------------------------------------------------------------------------
// MoveBackground
// DESCRIPTION:	Procedure updates background_yPos variable
//-----------------------------------------------------------------------------

procedure MoveBackground(	var yPos : Integer;
							const speed : Integer);
begin
	yPos += speed;
	if (yPos > ScreenHeight()) // Moving
	and ( speed > 0 ) then // AND off bottom?
		yPos -= BitmapHeight(BitmapNamed('background')) // Bring it back up top
	else if (yPos < 0) and ( speed < 0 ) then // Off top and moving backwards?
		yPos += BitmapHeight(BitmapNamed('background')); // Put it below.
end;

//-----------------------------------------------------------------------------
// MoveBalloon
// DESCRIPTION:	Procedure updates balloon xPos and will the real balloon
//				back to where the balloon's drawn copy was so that the copy
//				does not 'replace' the 'real' balloon
//-----------------------------------------------------------------------------

procedure MoveBalloon(	var xPos : Integer;
						var status : BalloonPosition;
						const speed : Integer;
						dir : Direction);
begin
	if dir = left then // Moving left?
		xPos -= speed
	else if dir = right then // Moving right?
		xPos += speed;
end;

//-----------------------------------------------------------------------------
// CheckBalloonPosition
// DESCRIPTION:	Procedure checks if balloon is off screen either due to
//				movement or because balloon has been pushed by cloud
//-----------------------------------------------------------------------------

procedure CheckBalloonPosition(	var xPos : Integer;
								var status : BalloonPosition);
begin
	if xPos < 0 then  // Balloon off screen (left)?
	begin
		status := offLeft;
		// x
		if xPos < -BitmapWidth(BitmapNamed('balloon')) then
		begin
			// Return back to right.
			xPos := ScreenWidth() - BitmapWidth(BitmapNamed('balloon'));
			status := offRight
		end;
	end
	// Else balloon off screen (right)?
	else if xPos + BitmapWidth(BitmapNamed('balloon')) > ScreenWidth() then
	begin
		status := offRight;
		// Fully past rightmost outer-screen limits?å
		if xPos > ScreenWidth() then
		begin
			xPos := 0; // Return back to left.
			status := offLeft;
		end;
	end
	else // Not off screen?
		status := normal;
end;

//-----------------------------------------------------------------------------
// MoveDarts
// DESCRIPTION:	Procedure moves darts down the screen and checks if off screen
//-----------------------------------------------------------------------------

procedure MoveDarts(	var darts : array of DartData;
						const dartLimit, speed : Integer);
var
	i : Integer;
begin
	for i := Low(darts) to High(darts) do // For every dart in the game
	begin
		if i <= dartLimit then // The i'th dart does not exceed dart?
		begin
			darts[i].yPos += speed; // Move darts down
			// Dart is now on screen?
			if darts[i].yPos + BitmapHeight(BitmapNamed('dart')) > 0 then
				darts[i].onScreen := true;
			// The i'th dart is off the screen?
			if darts[i].yPos > ScreenHeight() then
				LoopDart(darts[i]); // Loop i'th dart back up top.
		end
		// Else the i'th dart does exceed dart limit and still on screen?
		else if not darts[i].onScreen then
			LoopDart(darts[i]); // Loop i'th dart back up top.
	end;
end;

//-----------------------------------------------------------------------------
// MoveCloud
// DESCRIPTION: Procedure moves a cloud left or right and checks if off
//				screen
//-----------------------------------------------------------------------------

procedure MoveCloud(	var cloud : CloudData;
						const speed : Integer);
begin
	if cloud.onScreen then // Cloud is on the screen?
	begin
		if cloud.dir = right then // Cloud is currently moving left?
		begin
			cloud.xPos += Round(speed/2);
			if cloud.xPos >= ScreenWidth() then // If off screen?
			begin
				cloud.onScreen := false;
				cloud.xPos := ScreenWidth(); // Keep it off screen
			end;
		end
		else if cloud.dir = left then // Cloud is currently moving right?
		begin
			cloud.xPos -= Round(speed/2);
			// If off screen?
			if cloud.xPos <= -BitmapWidth(BitmapNamed('cloud')) then
			begin
				cloud.onScreen := false;
				// Keep it off screen
				cloud.xPos := -BitmapWidth(BitmapNamed('cloud'));
			end;
		end;
	end;
end;

//-----------------------------------------------------------------------------
// MoveHealth
// DESCRIPTION: Procedure moves the health down the screen and checks if off
//				screen
//-----------------------------------------------------------------------------

procedure MoveHealth(	var health : HealthData;
						const speed : Integer);
begin
	if health.onScreen then
	begin
		health.yPos += speed * 2;
		if health.yPos > ScreenHeight() then
			health.onScreen := false;
	end;
end;

//-----------------------------------------------------------------------------
// SpawnHealth
// DESCRIPTION: Creates a health pack at a random x position above screen
//-----------------------------------------------------------------------------

procedure SpawnHealth(	var health : HealthData;
						const balloon : BalloonData);
begin
	begin
		health.onScreen := true;
		health.xPos := RandomRange(	30,
									ScreenWidth()-30);
		health.yPos := RandomRange(	-BitmapHeight(BitmapNamed('dart')),
									-ScreenHeight());
	end

end;

//-----------------------------------------------------------------------------
// SubtractLife
// DESCRIPTION: Procedure subtracts a life and begins to die
//-----------------------------------------------------------------------------

procedure SubtractLife(	var ctrl : ControlData;
						var health : HealthData;
						const balloon: BalloonData);
begin
	PlaySoundEffect('loselife-1');
	if not (ctrl.playerLives <= 0) then // Player not out of lives?
			ctrl.playerLives -= 1; // Subtract a life
	if ctrl.playerLives <= 0 then // Player out of lives?
	begin
		// If player had achieved high score?
		if ctrl.playerScore = ctrl.highScore then
			WriteHighScore(ctrl.playerScore); // Write a high score to file
		StartTimer(health.dyingTimer);
		ctrl.gameSpeed := -4; // Start to fall to death
		SpawnHealth(health, balloon);
	end;
end;

//-----------------------------------------------------------------------------
// Collision With Balloon Function
// DESCRIPTION:	Function a boolean whether or not the balloon has collided
//				with the specified collision line or not. Two types of
//				collisions can occur; inner and outer balloon collisions.
//-----------------------------------------------------------------------------

function BalloonCollideWith(	balloon : BalloonData;
								collisionLine : LineSegment;
								collisionType : String):Boolean ;
const
	BALLOONTRI_INNERSCALE = 17;
var
	balloonTri : array [0..1] of Triangle;
	i : Integer;
begin
	// SET UP COLLISION TRIANGLES
	// Populate the array balloonTri_Inner and balloonTri_Outer where:
	// 		-    The index 0 refers to a normal balloon state(not off edge)
	// 		-    The index 1 refers to a right balloon state (off left edge)
	// 		- OR the index 1 refers to a left balloon state  (off right edge)

	// Populates null triangles so that it won't interfere later on
	balloonTri[0] := CreateTriangle(-1000,-1000,-1000,-1000,-1000,-1000);
	balloonTri[1] := CreateTriangle(-1000,-1000,-1000,-1000,-1000,-1000);

	for i := Low(balloonTri) to High(balloonTri) do
	begin
		// Balloon off screen (left) and checking second triangle?
		if (balloon.status = offLeft) and (i = 1) then
			// Check for copy on other side of screen (right).
			balloon.xPos := balloon.xPos + ScreenWidth()
		// Balloon off screen (right) and checking second triangle?
		else if (balloon.status = offRight) and (i = 1) then
			// Check for copy on other side of screen (left).
			balloon.xPos := balloon.xPos - ScreenWidth()
		// Balloon normal and checking second triangle?
		else if (balloon.status = normal) and (i = 1) then
			// Don't need to check for a second triangle since it's not off screen!
			break;
		if collisionType = 'outer' then
	    	// Create Outer Triangle to test against
	    	balloonTri[i] := CreateTriangle({X1}balloon.xPos,
	    									{Y1}BALLOON_YPOS+BitmapHeight(BitmapNamed('balloon'))/2,
											{X2}balloon.xPos+BitmapWidth(BitmapNamed('balloon'))/2,
											{Y2}BALLOON_YPOS,
											{X3}balloon.xPos+BitmapWidth(BitmapNamed('balloon')),
											{Y3}BALLOON_YPOS+BitmapHeight(BitmapNamed('balloon'))/2)
	    else if collisionType = 'inner' then
		    // Create Inner Triangle to test against
			balloonTri[i] := CreateTriangle({X1}balloon.xPos+BALLOONTRI_INNERSCALE,
											{Y1}BALLOON_YPOS+BitmapHeight(BitmapNamed('balloon'))/2,
											{X2}balloon.xPos+BitmapWidth(BitmapNamed('balloon'))/2,
											{Y2}BALLOON_YPOS+BALLOONTRI_INNERSCALE * 1.7,
											{X3}balloon.xPos+BitmapWidth(BitmapNamed('balloon'))-BALLOONTRI_INNERSCALE,
											{Y3}BALLOON_YPOS+BitmapHeight(BitmapNamed('balloon'))/2);

		// Result will be if EITHER (or) triangle has collided with collision line
		result := 	(TriangleLineCollision(balloonTri[0], collisionLine))
					or (TriangleLineCollision(balloonTri[1], collisionLine));

		// { DEBUG ONLY }
		// if KeyDown(vk_D) then
		// begin
		// 	// Draw collision triangles
		// 	DrawTriangle(ColorGreen, balloonTri[0]);
		// 	DrawTriangle(ColorRed, balloonTri[1]);
		// 	DrawLine(ColorBlue, collisionLine);
		// 	RefreshScreen(60);
		// end;
		// { /DEBUG ONLY }
	end;
end;

//-----------------------------------------------------------------------------
// BalloonCollideDarts
// DESCRIPTION: Check balloon collisions with dart; take a life in inner
//				collision otherwise do not take a life (play warning instead)
//-----------------------------------------------------------------------------

procedure BalloonCollideDarts(	var balloon : BalloonData;
								var darts : array of DartData;
								var ctrl : ControlData;
								var health : HealthData);
var
	i : Integer;
	CollisionLine : LineSegment;
begin
	for i := Low(darts) to ctrl.dartLimit do
	begin
		if darts[i].onScreen then // only apply to darts on screen
		begin
			CollisionLine := CreateLine({X1}darts[i].xPos,
										{Y1}darts[i].yPos
											+BitmapHeight(BitmapNamed('dart')),
										{X2}darts[i].xPos
											+BitmapWidth(BitmapNamed('dart')),
										{Y2}darts[i].yPos
											+BitmapHeight(BitmapNamed('dart')));
			// Outer balloon collisions with dart?
			if BalloonCollideWith(balloon, collisionLine, 'outer') then
			begin
			 	// Wiggle the balloon side to side as warning for too close
				MoveBalloon(balloon.xPos, balloon.status, RandomRange(-4,4), right);
				PlaySoundEffect('slidepast-1'); // Warning noise
				break;
			end;
			// Inner balloon collisions with dart?
			if BalloonCollideWith(balloon, collisionLine, 'inner') then
			begin
				LoopDart(darts[i]); // Loop i'th dart back up top.
				SubtractLife(ctrl, health, balloon); // Take life
				break;
			end;
		end;
	end;
end;

//-----------------------------------------------------------------------------
// BalloonCollideCloud
// DESCRIPTION: Check balloon collisions with cloud;
//				Force the balloon in cloud dir if collided
//-----------------------------------------------------------------------------

procedure BalloonCollideCloud(	var balloon : BalloonData;
								const cloud : CloudData;
								var ctrl : ControlData);
var
	CollisionLine : LineSegment;
begin
	if cloud.dir = left then // Cloud moving right?
	begin
		// Collision Line created for lefthand side of cloud
		CollisionLine := CreateLine({X1}cloud.xpos,
									{Y1}BALLOON_YPOS
										+BALLOON_YPOS_ADD,
									{X2}cloud.xpos,
									{Y2}BALLOON_YPOS
										+BALLOON_YPOS_ADD
										+BitmapHeight(BitmapNamed('cloud')));
		// Inner balloon collisions with cloud?
		if BalloonCollideWith(balloon, CollisionLine, 'inner') then
			// Jiggle balloon left.
			balloon.xPos -= Abs(ctrl.gameSpeed * 2);
	end;
	if cloud.dir = right then // Cloud moving right?
	begin
		// Collision Line created for righthand side of cloud
		CollisionLine := CreateLine({X1}cloud.xpos
										+BitmapWidth(BitmapNamed('cloud')),
									{Y1}BALLOON_YPOS
										+BALLOON_YPOS_ADD,
									{X2}cloud.xpos
										+BitmapWidth(BitmapNamed('cloud')),
									{Y2}BALLOON_YPOS
										+BALLOON_YPOS_ADD
										+BitmapHeight(BitmapNamed('cloud')));
		// Inner balloon collisions with cloud?
		if BalloonCollideWith(balloon, CollisionLine, 'inner') then
			// Jiggle balloon right
			balloon.xPos += Abs(ctrl.gameSpeed * 2);
	end;
end;

//-----------------------------------------------------------------------------
// BalloonCollideHealth
// DESCRIPTION: Check balloon collisions with health;
//				increase a life on collision
//-----------------------------------------------------------------------------

procedure BalloonCollideHealth(	const balloon : BalloonData;
								var health : HealthData;
								var ctrl : ControlData);
var
	CollisionLine : LineSegment;
begin
	// Collision Line created for a health pack
	CollisionLine := CreateLine({X1}health.xPos,
								{Y1}health.yPos
									+BitmapHeight(BitmapNamed('health')),
								{X2}health.xPos
									+BitmapWidth(BitmapNamed('health')),
								{Y2}health.yPos
									+BitmapHeight(BitmapNamed('health')));
	// Outer balloon collisions with health pack?
	if BalloonCollideWith(balloon, CollisionLine, 'outer') then
	begin
		// Sound effect of dying already playing?
		if SoundEffectPlaying('die-1') then
			// Stop sound effect if recovered from death.
			StopSoundEffect('die-1');
		PlaySoundEffect('health');
		ctrl.playerLives += 1; // Add a life.
		health.xPos := -1000; // Make sure its off screen.
		health.onScreen := false;
	end;
end;

//-----------------------------------------------------------------------------
// SpawnCloud
// DESCRIPTION: Creates a moving cloud at a from a random side on the screen
//-----------------------------------------------------------------------------

procedure SpawnCloud(var cloud : CloudData);
begin
	cloud.onScreen := true;

	// 50-50 chance on which side cloud will spawn on
	if Rnd(2) = 0 then
	begin
		// Moving right
		cloud.dir := right;
		// Put it on left (to move right).
		cloud.xPos := -BitmapWidth(BitmapNamed('cloud'));
	end
	else if Rnd(2) = 1 then
	begin
		// Moving left
		cloud.dir := left;
		// Put it on right (to move left).
		cloud.xPos := ScreenWidth() + BitmapWidth(BitmapNamed('cloud'));
	end;
end;

//-----------------------------------------------------------------------------
// UpdateScore
// DESCRIPTION: Procedure updates the score
// 				Player temp score returns the player back to (half way) of
//				original score before death to their previous score if they
//				recovered from death.
//-----------------------------------------------------------------------------

procedure UpdateScore(	var ctrl : ControlData;
						var health : healthData;
						const balloon : balloonData);
begin
	// For every ~1 second (depends on gameSpeed)
	if (TimerTicks(ctrl.scoreTimer) >= (3000 / ctrl.gameSpeed))
	// AND postive gameSpeed (i.e. not dying)
	and (ctrl.gameSpeed > 0) and (ctrl.playerLives > 0) then
	begin
		ctrl.playerScore += 1; // Increment score by 1
		ResetTimer(ctrl.scoreTimer);

		// Actual score < temp score? (recovered)
		if ctrl.playerScore < ctrl.playerTempScore then
		begin
		 	// Set player score to temp score
			ctrl.playerScore += Round((ctrl.playerTempScore - ctrl.playerScore) / 2);
			ctrl.playerTempScore := ctrl.playerScore;
		end
		// Else actual score >= temp score? (Normal)
		else if ctrl.playerScore >= ctrl.playerTempScore then
			// Set temp score to player score
			ctrl.playerTempScore := ctrl.playerScore;

		// If current score > high score?
		if ctrl.playerScore > ctrl.highScore then
			// Set the high score to the current score.
			ctrl.highScore := ctrl.playerScore;
	end
	else if ctrl.playerLives <= 0 then // Player is dead!
	begin
		if TimerTicks(health.dyingTimer) >= 2500 then // Every 2500ms?
		begin
			ResetTimer(health.dyingTimer);
			SpawnHealth(health, balloon);
		end;
		if TimerTicks(ctrl.scoreTimer) >= 100 then // Every 100ms?
		begin
			ctrl.playerScore -= 3; // Decrement score by 3
			// Play die sound if not playing already
			if not SoundEffectPlaying('die-1') then
				PlaySoundEffect('die-1');
			ResetTimer(ctrl.scoreTimer);
		end
		// Else, once player has depleted their score?
		else if ctrl.playerScore <= 0 then
		begin
			StopMusic();
			// Game over screen
			ClearScreen(ColorRed);
			FillRectangle(ColorBlack, 55, 210, 285, 75);
			DrawText('G A M E   O V E R', ColorWhite, 'pixel', 105, 235);
			RefreshScreen();
			// Play die-2 sound if not playing already
			// but only if 1st one is still playing
			if 	(not SoundEffectPlaying('die-2'))
				and (SoundEffectPlaying('die-1')) then
			begin
				StopSoundEffect('die-1');
				PlaySoundEffect('die-2');
			end;
			Delay(4000);
			ctrl.resetGame := true; // Reset the game
		end;
	end;
end;

//-----------------------------------------------------------------------------
// UpdateDifficulty
// DESCRIPTION: Procedure increases game difficulty based on score
//-----------------------------------------------------------------------------

procedure UpdateDifficulty(	var ctrl : ControlData;
							var cloud : CloudData;
							var health : HealthData;
							const balloon : BalloonData);
var
	healthChance, cloudChance : Double;
begin
	// Control given that player have lives?
	if not (ctrl.playerLives <= 0) then
	begin
		case ctrl.playerScore of
			0..9: // round one
			begin
				ctrl.dartLimit := 3;
				ctrl.gameSpeed := 3;
				healthChance := 0;
				cloudChance := 0;
			end;
			10..19: // round two
			begin
				ctrl.dartLimit := 4;
				ctrl.gameSpeed := 3;
				healthChance := 0.50;
				cloudChance  := 0;
			end;
			20..29: // round three
			begin
				ctrl.dartLimit := 5;
				ctrl.gameSpeed := 4;
				healthChance := 0.10;
				cloudChance  := 0.10;
			end;
			30..39: // round four
			begin
				ctrl.dartLimit := 8;
				ctrl.gameSpeed := 4;
				healthChance := 0.20;
				cloudChance  := 0.20;
			end;
			40..49: // round five
			begin
				ctrl.dartLimit := 10;
				ctrl.gameSpeed := 5;
				healthChance := 0.30;
				cloudChance  := 0.30;
			end;
			50..59: // round six
			begin
				ctrl.dartLimit := 12;
				ctrl.gameSpeed := 5;
				healthChance := 0.50;
				cloudChance  := 0.50;
			end;
			60..69:
			begin
				ctrl.dartLimit := 14;
				ctrl.gameSpeed := 6;
				healthChance := 0.40;
				cloudChance  := 0.60;
			end;
			70..79: // round seven
			begin
				ctrl.dartLimit := 16;
				ctrl.gameSpeed := 6;
				healthChance := 0.20;
				cloudChance  := 0.60;
			end;
			80..89: // round eight
			begin
				ctrl.dartLimit := 18;
				ctrl.gameSpeed := 7;
				healthChance := 0.20;
				cloudChance  := 0.65;
			end;
			else // > round eight
			begin
				ctrl.dartLimit := MAX_DARTS;
				ctrl.gameSpeed := 7;
				healthChance := 0.20;
				cloudChance  := 0.65;
			end;
		end;
	end;

	if TimerTicks(ctrl.chanceTimer) >= 3500 then
	begin
		// If not cloud on screen
		// AND random number is < chance possibility
		if 	not (cloud.onScreen)
		and (Rnd(99) < cloudChance * 100) then
			SpawnCloud(cloud);

		// If not health on screen
		// AND random number is < chance possibility
		if	not (health.onScreen)
			and (Rnd(99) < healthChance * 100) then
			SpawnHealth(health, balloon);

		ResetTimer(ctrl.chanceTimer);
	end;
end;

//============================================================================
// CheckKeys
// DESCRIPTION:	Procedure checks for any key presses for both
//				in-game/not in-game functionality
//============================================================================

procedure CheckKeys(	var menu : Boolean;
						var balloon : BalloonData;
						const speed : Integer;
						const playerScore : Integer;
						var highScore : Integer);
begin
	// Switch between in-game/not in-game on KeyDown(P)
	if KeyDown(vk_P) then
	begin
		menu := not menu;
		if playerScore = highScore then // If player has achieved high score?
			WriteHighScore(playerScore); // Write a high score to file
		PlaySoundEffect('menu');
		Delay(400);
	end;

	// Resets high score
	if KeyTyped(VK_N) then
	begin
		highScore := 0;
		NewHighScoreFile(true);
	end;

	// In-Game Key Presses
	if not menu then
	begin
		if KeyDown(vk_LEFT) then
			MoveBalloon(balloon.xPos, balloon.status, speed, left);
		if KeyDown(vk_RIGHT) then
			MoveBalloon(balloon.xPos, balloon.status, speed, right);
	end;

end;

//============================================================================
// UpdateGame
// DESCRIPTION:	Procedure will update all in-game variables.
//				Uses the above procedures for functional decomposition!
//============================================================================

procedure UpdateGame(	var balloon : BalloonData;
						var darts : array of DartData;
						var cloud : CloudData;
						var health : HealthData;
						var ctrl : ControlData);
begin
	// Move non-player entities
	MoveBackground(ctrl.background_yPos, ctrl.gameSpeed);
	MoveDarts(darts, ctrl.dartLimit, ctrl.gameSpeed);
	MoveCloud(cloud, Abs(ctrl.gameSpeed));
	MoveHealth(health, Abs(ctrl.gameSpeed));

	// Check balloon position
	CheckBalloonPosition(balloon.xPos, balloon.status);

	// Update score and difficulty
	UpdateScore(ctrl, health, balloon);
	UpdateDifficulty(ctrl, cloud, health, balloon);

	// Check for balloon collisions with other entities
	BalloonCollideDarts(balloon, darts, ctrl, health);
	BalloonCollideCloud(balloon, cloud, ctrl);
	BalloonCollideHealth(balloon, health, ctrl);

	if ctrl.resetGame then // A reset game has been called?
		// Reinitialise the game.
		Initialise(balloon, darts, cloud, health, ctrl);
end;

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//							DRAW PROCEDURES
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

//-----------------------------------------------------------------------------
// DrawBackground
// DESCRIPTION:	Draw background (one over the other for simulated loop)
//-----------------------------------------------------------------------------

procedure DrawBackground(const yPos : Integer);
begin
	DrawBitmap('background', 0, yPos);
	if yPos > 0 then // Background goes beyond 0 (does not cover whole screen)?
		DrawBitmap(	'background',
					0,
					// Draw a copy of the background above it.
					yPos - BitmapHeight(BitmapNamed('background')));
end;

//-----------------------------------------------------------------------------
// DrawBalloon
// DESCRIPTION:	Draw balloon and its copies if needed (i.e. if off screen)
//-----------------------------------------------------------------------------

procedure DrawBalloon(	const xPos : Integer;
						const status : BalloonPosition);
begin
	DrawBitmap('balloon', xPos, BALLOON_YPOS);
	if status = offLeft then // Balloon off screen (left)?
		// Draw a copy on other side of screen (right).
		DrawBitmap('balloon', xPos + ScreenWidth(), BALLOON_YPOS)
	else if status = offRight then  // Balloon off screen (right)?
		// Draw a copy on other side of screen (left).
		DrawBitmap('balloon', xPos - ScreenWidth(), BALLOON_YPOS);
end;

//-----------------------------------------------------------------------------
// DrawDarts
// DESCRIPTION:	Draws all darts (if the dart if on screen)
//-----------------------------------------------------------------------------

procedure DrawDarts(	const darts : array of DartData;
						const dartLimit : Integer);
var
	i : Integer;
begin
	for i := Low(darts) to dartLimit do
		if darts[i].onScreen then
			DrawBitmap('dart', darts[i].xPos, darts[i].yPos);
end;

//-----------------------------------------------------------------------------
// DrawCloud
// DESCRIPTION:	Draw a cloud in rotated in the appopriate direction
//-----------------------------------------------------------------------------

procedure DrawCloud(const cloud : CloudData);
begin
	if cloud.dir = left then
		// Rotated depended on direction
		DrawBitmap(	RotateScaleBitmap(BitmapNamed('cloud'), -180, 1),
					cloud.xPos,
					BALLOON_YPOS + BALLOON_YPOS_ADD)
	else if cloud.dir = right then
		DrawBitmap(	RotateScaleBitmap(BitmapNamed('cloud'), 0, 1),
					cloud.xPos,
					BALLOON_YPOS + BALLOON_YPOS_ADD);
end;

//-----------------------------------------------------------------------------
// DrawHealth
// DESCRIPTION:	Draw a health entity if on screen
//-----------------------------------------------------------------------------

procedure DrawHealth(const health : HealthData);
begin
	//if health.onScreen then
		DrawBitmap('health', health.xPos, health.yPos);
end;

//-----------------------------------------------------------------------------
// DrawHUD
// DESCRIPTION:	Draw a HUD for score and health; blink if dying!
//-----------------------------------------------------------------------------

procedure DrawHUD(const playerScore, highScore, playerLives : String);
var
	scoreColor : Color;
begin
	if 	(Trunc(GetTicks()/250) mod 2 = 0)  // Every 250 ms
	and (StrToInt(playerLives) <= 0) then // And if player dying
		scoreColor := ColorRed // Warn them!
	else if playerScore = highScore then // Player has achieved a high score
		scoreColor := ColorYellow
	else
		scoreColor := ColorWhite; // Normal score color

	FillRectangle(ColorBlack, 0, ScreenHeight()-35, ScreenWidth(), 35);
	DrawText(	playerScore+' metres',
				scoreColor,'pixel',
				30,
				Round(ScreenHeight()-30));
	DrawText(	'Patches: '+playerLives,
				ColorWhite,
				'pixel',
				ScreenWidth()-120,
				Round(ScreenHeight()-30));

end;

//============================================================================
// DrawGame
// DESCRIPTION: Procedure will draw all bitmaps when in-game
//				Uses the above procedures for functional decomposition!
//============================================================================

procedure DrawGame(	const balloon : BalloonData;
					const darts : array of DartData;
					const cloud : CloudData;
					const health : HealthData;
					const ctrl : ControlData);
begin
	DrawBackground(ctrl.background_yPos);
	DrawBalloon(balloon.xPos, balloon.status);
	DrawDarts(darts, ctrl.dartLimit);
	DrawCloud(cloud);
	DrawHealth(health);
	// Pass in strings only
	DrawHUD(	IntToStr(ctrl.playerScore),
				IntToStr(ctrl.highScore),
				IntToStr(ctrl.playerLives));
	RefreshScreen(60);
end;

//============================================================================
// DrawMenu
// DESCRIPTION:	Procedure will draw a menu when not in-game
//============================================================================

procedure DrawMenu(const ctrl : ControlData);
var
	randomColor : Color;
begin
	randomColor := RandomRGBColor(8);

	// Main Square
	FillRectangle(ColorBlack, 55, 145, 285, 200);
	DrawText('DART', randomColor, 'menu', 125, 165);
	DrawText('DODGER', randomColor, 'menu', 87, 165 + 50);
	DrawText(	'Press P to Play / Pause',
				ColorWhite,
				'pixel',
				80,
				Round(ScreenHeight() / 2));
	Delay(120); //delay for flashy colours!

	// Bottom Strip
	FillRectangle(ColorBlack, 0, ScreenHeight()-35, ScreenWidth(), 35);
	DrawText(	'High Score: '+IntToStr(ctrl.highScore),
				ColorYellow,
				'pixel',
				Round(ScreenWidth() / 2 - 80),
				Round(ScreenHeight() - 30));

	// Refresh the Screen
	RefreshScreen(60);
end;

//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
//									MAIN
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

procedure Main();
var
	// Balloon Entity Declared
	balloon : BalloonData;
	// Array of Darts Declared
	darts : array [0..MAX_DARTS] of DartData;
	// Cloud Entity Declared
	cloud : CloudData;
	// Health Entity Declared
	health : HealthData;
	// Game Control Variables
	ctrl : ControlData;
begin
	// Initiate SwinGame
	OpenAudio();
	SetIcon('icon.png');
	OpenGraphicsWindow('Dart Dodger', 400, 600);
	LoadDefaultColors();
	ClearScreen(ColorBlue);
	RefreshScreen();

	// Initiate Program Resources and setup game
	LoadResources();
	Initialise(balloon, darts, cloud, health, ctrl);

	repeat
		ProcessEvents();
		CheckKeys(	ctrl.menu,
					balloon,
					ctrl.gameSpeed,
					ctrl.playerScore,
					ctrl.highScore);
		// If in game
		if not ctrl.menu then
		begin
			DrawGame(balloon, darts, cloud, health, ctrl);
			UpdateGame(balloon, darts, cloud, health, ctrl);
		end
		// Else in menu
		else if ctrl.menu then
			DrawMenu(ctrl);

	until WindowCloseRequested();

	// If player has achieved high score?
	if ctrl.playerScore = ctrl.highScore then
		// Write a high score to file
		WriteHighScore(ctrl.playerScore);

	ReleaseAllResources();
	ReleaseAllTimers();
	CloseAudio();

end;

begin
	Main();
end.
