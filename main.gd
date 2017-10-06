extends Node2D

onready var RootNode = get_tree().get_root().get_node("RootNode")
onready var WorldContainer = RootNode.get_node("WorldContainer")
onready var MainCamara = get_node("MainCamara")
const BasePlant = preload("baseplant.gd")

var screenSize #Vector2f
var worldBounds = Vector2(2048, 600)
var isDebug = 0

var ground_Start
var ground_Size
var air_Start 
var air_Size 

export var globalScale = 1
var globalMatrixWidth = 73
var globalMatrixHeight = 73
var globalMatrix
var lightMatrix
var nutrientMatrix
var waterMatrix

const UNDEFINED = 0
const AIR = -1
const DIRT = 1
const ROOT = 2
const STEM = 3
const LEAF = 4
const FLOWER = 5
const BLOCK = 6

const UP = Vector2(0, -1)
const TIME_SPEED = 200.0
const UPDATE_TIME = 1/30.0

var time = 0.0
var update_delay = 0.0
var daysPassed = 1
var days_since_last_event = 1
var dayOfLastEvent = 1
var worldEventDuration = 2 + rand_range(0, 2)
var isWorldEventActive = 0 #bool: chekcs if world event is ongoing
var isNight = 0 #bool: checks if its night
var isCloudy = 0 #bool: checks if its cloudy
var moonPos = Vector2(800, 90)
var sunPos = Vector2(100, 100)
var ambientLightLevel
var ambientLightColor = Color(1, 1, 1)

#Array of lightsources
var lights = []
#Array of all plants
var plants = []
#Dictionary of plants with genetic code
var plantGeneticDataBase = {}

func _init():
	randomize()

func _ready():
	#Seed random number generator
	randomize()
	var mutationFactor = rand_range(0.9, 1.1)
	
	#geneticCode (array) of baseplant:
	#[0] = growth rate (float)
	#[1] = max growth rate (float)
	#[2] = max_length (int)
	#[3] = allow branching? (int 0, 1)
	#[4] = initial energy (float)
	#[5] = max stem width (float)
	#[6] = max branch size (float) (distance from main stem)
	#[7] = branch_spacer (float) (distance between branch nodes)
	#[8] = branch_offset (Vector2f(lower area, upper area) (percentage between 0 and 1) (what area of plant can produce branches)
	#[9] = family (string) 
	plantGeneticDataBase = {"Short grass":[0.075 * mutationFactor, 
										   0.1 * mutationFactor,
										   21 * mutationFactor,
										   0,
										   10 * mutationFactor,
										   1 * mutationFactor,
										   0,
										   5,
										   Vector2(0.1, 0.1),
										   Color(0.61, 1, 0.61, 1),
										   Color(0.3, 1, 0.3, 1),
										   "GRASS",
										   1],
							
							"Tall grass":[0.1 * mutationFactor,
										  0.15 * mutationFactor,
										  42 * mutationFactor,
										  1,
										  10 * mutationFactor,
										  1.2 * mutationFactor,
										  9,
										  5 * mutationFactor,
										  Vector2(0.0 * mutationFactor, 0.12 * mutationFactor),
										  Color(0.61, 1, 0.61, 1),
										  Color(0.3, 1, 0.3, 1),
										  "GRASS",
										  1],
										
							"Bamboo":[0.2 * mutationFactor,
									  0.3 * mutationFactor,
								      84 * mutationFactor,
									  0,
								      34 * mutationFactor,
									  2 * mutationFactor,
									  0,
									  0,
									  Vector2(0, 0),
									  #Color(0.61, 1, 0.61, 1),
									  Color(1, 0, 0.0, 1),
									  Color(0.2, 1, 0.2, 1),
									  "GRASS",
									  1],
									
							"Giant cactus":[0.01 * mutationFactor,
											0.2 * mutationFactor,
											100 * mutationFactor,
											1,
											100 * mutationFactor,
											5.5 * mutationFactor,
											30 * mutationFactor,
											50 * mutationFactor,
											Vector2(0.1 * mutationFactor, 0.8 * mutationFactor),
											Color(0.93 * mutationFactor, 0.5 * mutationFactor, 0.93 * mutationFactor, 1),
											Color(0.08, 0.5, 0.1, 1),
											"CACTUS",
											0],

							"Palm":[0.15 * mutationFactor,
									0.35 * mutationFactor,
									135 * mutationFactor,
									1,
									100 * mutationFactor,
									5.7 * mutationFactor,
									20 * mutationFactor,
									15 * mutationFactor,
									Vector2(0.8 * mutationFactor, 0.95 * mutationFactor),
									Color(0.61, 1, 0.61, 1),
									Color(0.82, 0.41, 0.11, 1),
									"PALM",
									1],

							"Random plant":[rand_range(0.025, 0.4),
											rand_range(0.2, 0.4),
											int(rand_range(20, 370)),
											randi()%2,
											rand_range(30, 100),
											rand_range(1, 5.5),
											rand_range(1, 30),
											rand_range(10, 50),
											Vector2(rand_range(0.1, 0.5), rand_range(1, 2)),
											Color(rand_range(0.1, 1), rand_range(0.1, 1), rand_range(0.1, 1), 1),
											Color(rand_range(0.1, 1), rand_range(0.1, 1), rand_range(0.1, 1), 1),
											"RANDOM",
											randi()%2]
							}
	
	screenSize = get_viewport_rect().size #Vector2f
	time = 6.0;
	update_delay = 0.0;
	
	#Scaling global matrix
	globalMatrixWidth *= globalScale
	globalMatrixHeight *= globalScale
	
	#The global matrix 
	globalMatrix = []
	for x in range(globalMatrixWidth):
    globalMatrix.append([])
    for y in range(globalMatrixHeight):
        globalMatrix[x].append(0)

	#The light matrix 
	lightMatrix = []
	for x in range(globalMatrixWidth):
    lightMatrix.append([])
    for y in range(globalMatrixHeight):
        lightMatrix[x].append(0)

	#The nutrient matrix 
	waterMatrix = []
	for x in range(globalMatrixWidth):
    waterMatrix.append([])
    for y in range(globalMatrixHeight):
        waterMatrix[x].append(0)

	#The water matrix 
	waterMatrix = []
	for x in range(globalMatrixWidth):
    waterMatrix.append([])
    for y in range(globalMatrixHeight):
        waterMatrix[x].append(0)

	#WorldContainer.set_size(Rect2(Vector2(0, 0), worldBounds))
	#Define ground area
	ground_Start = Vector2(WorldContainer.get_pos().x, WorldContainer.get_pos().y+(WorldContainer.get_size().y*0.75))
	ground_Size = Vector2(WorldContainer.get_size().x, WorldContainer.get_size().y*0.25)
	#Define air area 
	air_Start = Vector2(WorldContainer.get_pos())
	air_Size = Vector2(WorldContainer.get_size().x, WorldContainer.get_size().y*0.75)

	#/+++++FOR DEBUGGING ONLY+++++\
	#Add some random plants
	#for i in range(0, int(rand_range(1, 30))):
	#	randomize()
	#	add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Random plant"])
	#add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Tall grass"])
	#Add bamboo
	#for i in range(0, int(rand_range(1, 11))):
	#	randomize()
	#	add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Bamboo"])
	#add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Palm"])
	#add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Giant cactus"])
	#add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Bamboo"])
	#add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Bamboo"])
	#add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Random plant"])
	#add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Tall grass"])
	#add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Short grass"])
	#\+++++FOR DEBUGGING ONLY+++++/
	firstRun()
	set_process(true)
	set_process_input(true)

#Generate inital plants here
#It is best to create biggest plants first and then smallests
func firstRun():
	#Add some random plants
#	for i in range(0, int(rand_range(1, 6))):
#		randomize()
#		add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Random plant"])
	for i in range(0, int(rand_range(10, 20))):
		randomize()
		add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Palm"])
	#Add some giant cacti
	for i in range(0, int(rand_range(2, 10))):
		randomize()
		add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Giant cactus"])
	#add some Bamboo
	for i in range(0, int(rand_range(1, 10))):
		randomize()
		add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Bamboo"])
	#Add some long grasses
	for i in range(0, int(rand_range(11, 56))):
		add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Tall grass"])
	#Add some short grasses
	for i in range(0, int(rand_range(19, 67))):
		randomize()
		add_plant(Vector2(int(rand_range(10, 1000)), ground_Start.y), plantGeneticDataBase["Short grass"])

#Used for day / night cycle
func calculate_ambient_lightning(hour, minute):
	var lightningMin = 0.3
	var lightningMax = 1.0
	var time = (hour + (minute / 60.0)) / 24.0
	var light
	if(isCloudy == 0):
		light = lightningMax * sin(PI*time)
	else:
		light = (lightningMax * sin(PI*time)) * rand_range(0.6, 0.8)
	return clamp(light, lightningMin, lightningMax)

#Main loop
func _process(delta):
	#Update time
	time += 1/60.0*TIME_SPEED*delta
	if time >= 24.0:
		time -= 24.0
		daysPassed += 1
	
	#Update delay
	update_delay -= delta
	if update_delay > 0.0:
		return
	update_delay = UPDATE_TIME
	
	#World events
	days_since_last_event = abs(daysPassed - dayOfLastEvent)
	if(days_since_last_event > int(rand_range(14, 21)) + int(rand_range(0, 9))):
		isWorldEventActive = 1
		days_since_last_event = 0
		dayOfLastEvent = daysPassed
	if(days_since_last_event < worldEventDuration and isWorldEventActive == 1):
		isCloudy = 1
	if(days_since_last_event >= worldEventDuration and isWorldEventActive == 1):
		isCloudy = 0
		isWorldEventActive = 0
			
	#Day and night cycle calculations
	#var sunmoon_angle = deg2rad(360*(time/24.0))
	#sunPos = Vector2(sunPos.x, sunPos.y + sunmoon_angle)
	#moonPos = Vector2(moonPos.x, moonPos.y + sunmoon_angle)
	#Calculate ambient light level
	ambientLightLevel = calculate_ambient_lightning(floor(time), (time-floor(time))*60)
	#Calculate ambient light color
	ambientLightColor = Color(1, 0.9, 0.9, 1) #Daylight color
	isNight = 0
	#Evening color
	if time >= 17.5 && time < 18:
		var d = (time-17.5)/0.5
		ambientLightColor = Color(1-((1-42/255.0)*d), 1-((1-64/255.0)*d), 1-((1-141/255.0)*d), 1)
	#Morning color
	elif time >= 5.5 && time < 6.0:
		var d = (time-5.5)/0.5
		ambientLightColor = Color(0.164+((1-42/255.0)*d), 0.250+((1-64/255.0)*d), 0.552+((1-141/255.0)*d), 1)
	#Night color
	elif time >= 18 || time < 5.5:
		ambientLightColor = Color(0.164, 0.250, 0.552, 1)
		isNight = 1
	
	#Drawing
	update()
	
	if(isDebug == 1): pass
	#	print("Time: " + str(time))
	#	print("Light level: " + str(ambientLightLevel))
	#var rand = rand_range(0.9, 1.1)
	#print("rand = " + str(rand))
	
	#Update light matrix
#	for i in range(lights.size()):
#		light = lights[i]
#		source = Vector2(light.x, light.y)
#		lightMatrix[source.x][source.y] = light.intensity
		
func _draw():
	#Draw the air
	draw_rect(Rect2(air_Start, air_Size), Color(0*ambientLightColor.r, 1*ambientLightColor.g, 1*ambientLightColor.b, 0.7))
	#Draw day and night
	if time < 5.5 || time >= 18.0:
		#Draw the stars
		#for i in range(0, 60):
		#	draw_circle(Vector2(rand_range(air_Start.x, air_Start.y), rand_range(air_Size.x, air_Size.y)), 5, Color(0.9, 0.9, 0.9))
		#Draw the moon
		draw_circle(moonPos, 45, Color(0.75, 0.75, 0.75, 1))
	else:
		#Draw the sun
		draw_circle(sunPos, 48, Color(1, 1, 0, 1))
	#Draw the clouds
	if(isCloudy == 1):
		draw_circle(Vector2(sunPos.x + 20, sunPos.y - 15), 29, Color(1, 1, 1, 0.6))
		draw_circle(Vector2(sunPos.x + 30, sunPos.y - 30), 20, Color(1, 1, 1, 0.6))
		draw_circle(Vector2(sunPos.x + 38, sunPos.y - 15), 35, Color(1, 1, 1, 0.6))
		
		draw_circle(Vector2(sunPos.x + 370, sunPos.y - 55), 34, Color(1, 1, 1, 0.6))
		draw_circle(Vector2(sunPos.x + 380, sunPos.y - 75), 25, Color(1, 1, 1, 0.6))
		draw_circle(Vector2(sunPos.x + 388, sunPos.y - 55), 40, Color(1, 1, 1, 0.6))
		
		draw_circle(Vector2(moonPos.x - 20, moonPos.y - 20), 29, Color(1, 1, 1, 0.6))
		draw_circle(Vector2(moonPos.x - 30, moonPos.y - 35), 20, Color(1, 1, 1, 0.6))
		draw_circle(Vector2(moonPos.x - 38, moonPos.y - 20), 35, Color(1, 1, 1, 0.6))
	
	#Draw the ground saddle brown
	draw_rect(Rect2(ground_Start, ground_Size), Color(0.54, 0.27, 0.007, 1))

#Input handling
func _input(event):
	if(event.is_pressed()):
		#Move camara right
		if(event.scancode == KEY_RIGHT):
			MainCamara.set_pos(MainCamara.get_pos() + Vector2(10, 0))
		#Move camara left
		if(event.scancode == KEY_LEFT):
			MainCamara.set_pos(MainCamara.get_pos() + Vector2(-10, 0))
		#Move camara up
		if(event.scancode == KEY_UP):
			MainCamara.set_pos(MainCamara.get_pos() + Vector2(0, -10))
		#Move camara down
		if(event.scancode == KEY_DOWN):
			MainCamara.set_pos(MainCamara.get_pos() + Vector2(0, 10))
		#Reset camara to orginal position and zoom
		if(event.scancode == KEY_R):
			MainCamara.set_pos(Vector2(512, 300))
			MainCamara.set_zoom(Vector2(1, 1))
		#Zoom camara in
		if(event.scancode == KEY_Q):
			MainCamara.set_zoom(MainCamara.get_zoom() + Vector2(0.1, 0.1))
		#Zoom camara out
		if(event.scancode == KEY_W):
			MainCamara.set_zoom(MainCamara.get_zoom() + Vector2(-0.1, -0.1))
		#Exit and close
		if(event.scancode == KEY_ESCAPE):
			get_tree().quit() 

func add_plant(tmp_pos, tmp_geneticCode, tmp_previousGenerationNumbr = 0):
	add_child(BasePlant.new(tmp_pos, tmp_geneticCode, tmp_previousGenerationNumbr))

func add_light(x, y, size, intensity):
	lights.append(LightSource.new(x, y, size, intensity))
	var light = lights[lights.size()-1]
	light.lightID = lights.size()-1
	light.set_name("LightSource_" + str(light.lightID))
	add_child(light)
	
func remove_light(id):
	lights[id].queue_free()
	lights.remove(id)