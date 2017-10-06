extends Node2D

onready var RootNode = get_tree().get_root().get_node("RootNode")
onready var Map = RootNode.get_node("WorldContainer/Map")

const col_green = Color(0, 1, 0, 1)
const col_lightGreen = Color(0.2, 1, 0.2, 1)
const col_brown = Color(0.4, 0.2, 0, 1)
const col_saddleBrown = Color(0.54, 0.27, 0.0, 1)
const col_white = Color(1, 1, 1, 1)
const col_none = Color(0, 0, 0, 0)
const UP = Vector2(0, -1)

export var position = Vector2(0, 0)
export var growth_rate = 0.1
export var max_growth_rate = 0.4
export var max_length = 100
export var can_Branch = 1 #Boolean (allows or denies branching)
export var energy = 100
export var max_stem_width = 5.5
export var max_branch_size = 30
export var branch_spacer = 20
export var branch_offset = Vector2(0.2, 0.8)
export var flower_color = col_white
export var stem_color = col_brown
export var family = "PLANT"
export var isMonocarpic = 0 #Monocarpic plants die after flowering
var min_length = 15
var max_energy = 500
var max_branches = 7
var numbrOfBranches = 0
var isFlowering = 0
var last_bloomDay = 0
var hasReproduced = 0
var generation = 0
var energy_percentage
var plant_length
var age
var birthDay
var genetic_code_size
#Array of all points making up the plant
var plant_dataPoints = []
#For debugging only
var GrowingDirection = [Vector2(0, 0), UP]

#Data structure of info every point in the plant
#Structure:
#[0] = Vector2 position
#[1] = Vector2 direction
#[2] = Color color
#[3] = String type 
#[4] = int birthDate
#[5] = float size
#Default types: SHOOT, STEM, BRANCH, ROOT, LEAF FLOWER, 
func new_data_point(tmp_pos, tmp_dir, tmp_birthDate, tmp_type):
	var plant_dataPoint = {}
	
	plant_dataPoint["position"] = tmp_pos
	plant_dataPoint["direction"] = tmp_dir.normalized()
	plant_dataPoint["type"] = tmp_type
	plant_dataPoint["birthDate"] = tmp_birthDate
	if(tmp_type == "SHOOT"):
		plant_dataPoint["color"] = col_lightGreen
		plant_dataPoint["size"] = max_stem_width * 0.5
	if(tmp_type == "STEM"):
		plant_dataPoint["color"] = stem_color
		plant_dataPoint["size"] = max_stem_width * 0.35
	if(tmp_type == "BRANCH"):
		plant_dataPoint["color"] = col_none
		plant_dataPoint["size"] = max_stem_width * 0.85
	if(tmp_type == "ROOT"):
		plant_dataPoint["color"] = col_white
		plant_dataPoint["size"] = max_stem_width * 0.33
	if(tmp_type == "LEAF"):
		plant_dataPoint["color"] = col_green
		plant_dataPoint["size"] = max_stem_width * 0.4
	if(tmp_type == "FLOWER"):
		plant_dataPoint["color"] = flower_color
		plant_dataPoint["size"] = max_stem_width * 0.42
	
	return plant_dataPoint

func _init(pos, tmp_geneticCode, tmp_previousGenerationNumbr = 0):
	position = pos
	#decoding genetic code
	growth_rate = tmp_geneticCode[0]
	max_growth_rate = tmp_geneticCode[1]
	max_length = tmp_geneticCode[2]
	can_Branch = tmp_geneticCode[3]
	energy = tmp_geneticCode[4]
	max_stem_width = tmp_geneticCode[5]
	max_branch_size = tmp_geneticCode[6]
	branch_spacer = tmp_geneticCode[7]
	branch_offset = tmp_geneticCode[8]
	flower_color = tmp_geneticCode[9]
	stem_color = tmp_geneticCode[10]
	family = tmp_geneticCode[11]
	isMonocarpic = tmp_geneticCode[12]
	genetic_code_size = tmp_geneticCode.size()
	#Create initial growth tip at base of seed
	plant_dataPoints.append(new_data_point(position, UP, 0, "SHOOT"))
	plant_length = 0
	age = 0
	isFlowering = 0
	generation = tmp_previousGenerationNumbr + 1
	#Prevent plant from having 0 max lenngth
	if(max_length <= min_length):
		max_length = min_length

func _ready():
	birthDay = Map.daysPassed
	set_process(true)
	
func _process(delta):
	#Add energy from photosynthesis
	energy += Map.ambientLightLevel
	energy_percentage = (energy/max_energy)
	age = Map.daysPassed - birthDay
	
	#Limit growth
	if(growth_rate >= max_growth_rate):
		growth_rate = max_growth_rate
	if(energy >= max_energy):
		energy = max_energy
	if(plant_length < 3.5):
		max_energy = 10
	else:
		max_energy = (plant_length * 0.6) + 10
	
	#Grow the plant
	grow()
	
	#Check if plant should reproduce or flower
	if(plant_length >= max_length):
		if(age >= 2 and isFlowering == 0):
			isFlowering = 1
			last_bloomDay = Map.daysPassed
		elif(Map.daysPassed - last_bloomDay <= 2 and isFlowering == 1):
			isFlowering = 0
		if(age >= 4):
			reproduce()
	#Check if plant should die
	if(energy <= 0 or hasReproduced == 1):
		death()
	#drawing
	update()
	
	if(Map.isDebug == 1 && max_energy != 10):
		print("+++")
		#print("position: = " + str(position))
		#print("Plant Energy = " + str(energy))
		#print("plant Length = " + str(plant_length))
		#print("plant max energy = " + str(max_energy))
		print("plant Age = " + str(age))
		#print("Energy %% = " + str(energy_percentage))
		print(str(isFlowering))
		
func _draw():
	#Draw plant
	if(plant_dataPoints.size() >= 1):
		for i in range(plant_dataPoints.size()-1):
			draw_circle(plant_dataPoints[i]["position"], plant_dataPoints[i]["size"], plant_dataPoints[i]["color"])
			#draw_line(plant_dataPoints[i][0], plant_dataPoints[i+1][0], plant_dataPoints[i][2], plant_dataPoints[i][5])
	#Draw plant origin (seed)
	if(energy_percentage != null and energy_percentage > 0):
		draw_circle(position, 1.6, Color(energy_percentage, energy_percentage, energy_percentage, 0.85))
	else:
		draw_circle(position, 1.6, Color(1, 0, 0, 0.85))
	#FOR DEBUG ONLY
	if(Map.isDebug == 1):
		var dir = GrowingDirection[1] #* Vector2(1.2, 1.2)
		draw_line(GrowingDirection[0], dir.normalized(), Color(1, 1, 1, 1), 3)
		#draw_circle(dir.normalized() * Vector2(0.5, 0.5), 3.5, Color(1, 0, 0, 1))

#Growth algorithm
func grow():
	for i in range(plant_dataPoints.size()):
		#Check plant for new "growth tips" (shoots) and then grow them
		if(plant_dataPoints[i]["type"] == "SHOOT"):
			#Calculate plant length
			plant_length = abs(position.y - plant_dataPoints[i]["position"].y)
			if(plant_length <= max_length):
				#Check if plant has enough energy to support new growth
				if(energy > 3):
					#Create new growth
					var newGrowthPos = plant_dataPoints[i]["position"] + Vector2(growth_rate*(Map.TIME_SPEED/200), growth_rate*(Map.TIME_SPEED/200)) * plant_dataPoints[i]["direction"]
					if(Map.isDebug == 1):
						GrowingDirection = [plant_dataPoints[i]["position"], newGrowthPos] #DEBUG ONLY
					if(abs(newGrowthPos.x - position.x) <= max_branch_size * rand_range(0.95, 1.05)):
						plant_dataPoints.append(new_data_point(newGrowthPos, plant_dataPoints[i]["direction"], 0, "SHOOT"))
					else:
						plant_dataPoints.append(new_data_point(newGrowthPos, UP, 0, "SHOOT"))
					#creating new growth requires energy
					energy -= 1.35 * rand_range(0.1, 2.0)
					#replace current or old growth tip with a stem or a flower
					plant_dataPoints[i] = new_data_point(newGrowthPos, plant_dataPoints[i]["direction"], Map.daysPassed, "STEM")
			#Branching algorithm
			elif(can_Branch == 1 and numbrOfBranches <= max_branches):
				#if(family == "CACTUS" and age <= 7):
				#	pass
				#Create new branch node
				#else:
				var branchNodePos = Vector2(position.x, position.y - rand_range(plant_length * branch_offset.x, plant_length * branch_offset.y))
				var branchNodeDir = Vector2(rand_range(-1, 1), rand_range(-1, 0))
				plant_dataPoints.remove(i)
				plant_dataPoints.append(new_data_point(branchNodePos, branchNodeDir, 0, "SHOOT"))
				plant_dataPoints.append(new_data_point(branchNodePos, branchNodeDir, 0, "BRANCH"))
				numbrOfBranches += 1
			#Flowering algorithm
			elif(isFlowering == 1):
				pass
		#Thicken the stem with age
		#it costs a small amount of energy to thicken stem
		elif(plant_dataPoints[i]["type"] == "STEM" and plant_dataPoints[i]["size"] < max_stem_width):
			var stemAge = Map.daysPassed - plant_dataPoints[i]["birthDate"]
			if(stemAge >= 3 and stemAge < 7):
				plant_dataPoints[i]["size"] = max_stem_width * 0.5
				#energy -= 0.01
			elif(stemAge > 10 and stemAge < 14):
				plant_dataPoints[i]["size"] = max_stem_width * 0.75
				#energy -= 0.01
			elif(stemAge > 14):
				plant_dataPoints[i]["size"] = max_stem_width
				energy -= 0.01
				
#encode all genetic plant variables in an array
func encode_geneticCode():
	var geneticCode = [growth_rate,
					   max_growth_rate,
					   max_length,
					   can_Branch,
					   35 * rand_range(0.9, 1.2),
					   max_stem_width,
					   max_branch_size,
					   branch_spacer,
					   branch_offset,
					   flower_color,
					   stem_color,
					   family,
					   isMonocarpic
					  ]
	return geneticCode

#Mixes 2 genetic codes and returns a new one
#Assumed that geneticCode_A is the dominant type
func mix_geneticCode(geneticCode_A, geneticCode_B):
	print("test")
	randomize()
	var mutationFactor = rand_range(0.95, 1.05)
	var geneticCode = [((geneticCode_A[0]+geneticCode_B[0]) / 2) * mutationFactor,
					   ((geneticCode_A[1]+geneticCode_B[1]) / 2) * mutationFactor,
					   ((geneticCode_A[2]+geneticCode_B[2]) / 2) * mutationFactor,
					   geneticCode_A[3],
					   ((geneticCode_A[4]+geneticCode_B[4]) / 2) * mutationFactor,
					   ((geneticCode_A[5]+geneticCode_B[5]) / 2) * mutationFactor,
					   ((geneticCode_A[6]+geneticCode_B[6]) / 2) * mutationFactor,
					   ((geneticCode_A[7]+geneticCode_B[7]) / 2) * mutationFactor,
					   ((geneticCode_A[8]+geneticCode_B[8]) / 2) * Vector2(mutationFactor, mutationFactor),
					   geneticCode_A[9],
					   geneticCode_A[10],
					   geneticCode_A[11]
					]
	return geneticCode

#Reproduction algorithm
func reproduce():
	#Check if have enough energy for reproduction
	if(energy_percentage > 0.65):
		var geneticCode = encode_geneticCode()
		var seedling_offsetPos = 15
		var rand = randi()%2
		#Reproduction by flowering
		if(isFlowering == 1):
			#Check if another flowering plant with same family is present
			seedling_offsetPos = rand_range(15, 33)
			for i in range(0, Map.plants.size()-1):
				#Cross pollination
				if(Map.plants[i].family == family and Map.plants[i].isFlowering == 1):
					geneticCode = mix_geneticCode(geneticCode, Map.plants[i].encode_geneticCode())
					print("cross pollination")
				#Self pollination
				else:
					geneticCode = mix_geneticCode(geneticCode, geneticCode)
					print("Self pollination")
		
		#Reproduction by cloning
		else:
			#Create new genetic code for offspring (Pass on genes)
			randomize()
			seedling_offsetPos = rand_range(15, 25)
			geneticCode = [growth_rate * rand_range(0.1, 1.8),
							max_growth_rate * rand_range(0.3, 1.5),
							max_length * rand_range(0.9, 1.1),
							can_Branch,
							35 * rand_range(0.9, 1.2),
							max_stem_width,
							max_branch_size * rand_range(0.95, 1.05),
							branch_spacer * rand_range(0.95, 1.05),
							Vector2(branch_offset.x * rand_range(0.95, 1.05), branch_offset.y * rand_range(0.95, 1.05)),
							flower_color,
							stem_color,
							family,
							isMonocarpic
							]
		#Create new seedling
		if(rand == 1):
			seedling_offsetPos *= -1
		Map.add_plant(Vector2(position.x + seedling_offsetPos, position.y), geneticCode, generation)
		if(isMonocarpic == 1):
			hasReproduced = 1
		hasReproduced = 1
		#self.energy -= 35
		self.energy -= (self.energy/100) * 65
	else:
		pass

func death():
	self.plant_dataPoints.clear() #for saving memory
	self.queue_free()
	