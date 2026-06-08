extends GutTest

var BotController = preload("res://source/bot_controller.gd")

func test_bot_controller_setup():
	var controller = BotController.new()
	var mock_gm = Node.new()
	controller.setup(mock_gm)
	
	assert_eq(controller.gm, mock_gm, "BotController should have mock_gm as the gm reference")
	
	controller.free()
	mock_gm.free()

class MockGM extends Node:
	var players = []

class MockPlayer:
	var resources = {}

func test_choose_resource_returns_rarest():
	var controller = BotController.new()
	var mock_gm = MockGM.new()
	
	var player = MockPlayer.new()
	player.resources = {
		"ore": 2,
		"wheat": 3,
		"sheep": 1,
		"wood": 0, 
		"brick": 5
	}
	
	mock_gm.players = [null, player]
	controller.setup(mock_gm)
	
	var rarest = controller.choose_resource(1)
	assert_eq(rarest, "brick", "should choose brick as monopoly target")
	
	controller.free()
	mock_gm.free()
