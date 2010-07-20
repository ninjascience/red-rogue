﻿package com.robotacid.dungeon {
	import com.robotacid.engine.Character;
	import com.robotacid.engine.CharacterAttributes;
	import com.robotacid.engine.Chest;
	import com.robotacid.engine.Effect;
	import com.robotacid.engine.Entity;
	import com.robotacid.engine.Item;
	import com.robotacid.engine.MapTileConverter;
	import com.robotacid.engine.Monster;
	import flash.display.DisplayObject;
	/**
	 * Creates content to place on the map for the first 20 levels to create structured
	 * play, then returns random content from the entire selection afterwards
	 *
	 * You'll notice that I'm shifting between XML and normal objects a lot. The logic behind this
	 * is that if I need to find out what's going on in a level, a quick print out of the XML renders
	 * an easily readable itinerary. And it takes up less room in the shared object.
	 *
	 * @author Aaron Steed, robotacid.com
	 */
	public class Content{
		
		public var chestsByLevel:Vector.<Vector.<XML>>;
		public var monstersByLevel:Vector.<Vector.<XML>>;
		
		public static const TOTAL_LEVELS:int = 20;
		
		public function Content() {
			chestsByLevel = new Vector.<Vector.<XML>>(TOTAL_LEVELS);
			monstersByLevel = new Vector.<Vector.<XML>>(TOTAL_LEVELS);
			init();
		}
		
		public function init():void{
			var equipment:Vector.<XML> = new Vector.<XML>();
			var runes:Vector.<XML> = new Vector.<XML>();
			var i:int, j:int;
			for(i = 0; i < TOTAL_LEVELS; i++){
				var quantity:int;
				var dungeonLevel:int = i + 1;
				// min: level / 2, max: (level + 2) / 2
				quantity = Math.ceil((dungeonLevel + Math.random() * 3) * 0.5);
				while(quantity--){
					equipment.push(createItemXML(dungeonLevel, Math.random() < 0.5 ? Item.WEAPON : Item.ARMOUR));
				}
				// min: level / 2, max: (level + 1) / 2
				quantity = Math.ceil((dungeonLevel + Math.random() * 2) * 0.5);
				while(quantity--){
					runes.push(createItemXML(dungeonLevel, Item.RUNE));
				}
				// min: 5 + level * 2, max: 10 + level 3
				quantity = 5 + Math.random() * 6 + dungeonLevel * (2 + Math.random() * 2);
				monstersByLevel[i] = new Vector.<XML>();
				while(quantity--){
					monstersByLevel[i].push(createCharacterXML(dungeonLevel, Character.MONSTER));
				}
				
				// equipment needs to be distributed amongst monsters and
				// runes need to go in chests
				var equippedMonsters:int = Math.random() * equipment.length;
				if(monstersByLevel[i].length < equippedMonsters) equippedMonsters = monstersByLevel[i].length;
				while(equippedMonsters--){
					monstersByLevel[i][equippedMonsters].appendChild(equipment.shift());
					
					// bonus equipment - if the order of the items alternates between
					// weapons and armour, we take it as a sign to double equip the
					// monster
					if(equippedMonsters){
						monstersByLevel[i][equippedMonsters].appendChild(equipment.shift());
						equippedMonsters--;
					}
				}
				chestsByLevel[i] = new Vector.<XML>();
				// the rest goes in chests, upto 3 items can go in a chest
				while(equipment.length || runes.length){
					var chestQuantity:int = 1 + Math.random() * 3;
					if(chestQuantity > equipment.length + runes.length) chestQuantity = equipment.length + runes.length;
					var chest:XML = <chest />;
					while(chestQuantity){
						if(Math.random() < 0.5){
							if(runes.length){
								chest.appendChild(runes.shift());
								chestQuantity--;
							}
						} else {
							if(equipment.length){
								chest.appendChild(equipment.shift());
								chestQuantity--;
							}
						}
					}
					chestsByLevel[i].push(chest);
				}
			}
		}
		
		public function populateLevel(dungeonLevel:int, bitmap:DungeonBitmap, layers:Array):void{
			var r:int, c:int;
			var level:int = dungeonLevel - 1;
			var i:int;
			//trace("populating..."+dungeonLevel);
			//for(i = 0; i < monstersByLevel[level].length; i++){
				//trace(monstersByLevel[level][i].toXMLString());
			//}
			//for(i = 0; i < chestsByLevel[level].length; i++){
				//trace(chestsByLevel[level][i].toXMLString());
			//}
			if(level < TOTAL_LEVELS){
				// just going to go for a random drop for now.
				// I intend to figure out a distribution pattern later
				while(monstersByLevel[level].length){
					r = 1 + Math.random() * (bitmap.height - 1);
					c = 1 + Math.random() * (bitmap.width - 1);
					if(!layers[Map.ENTITIES][r][c] && layers[Map.BLOCKS][r][c] != 1 && (bitmap.bitmapData.getPixel32(c, r + 1) == DungeonBitmap.LEDGE || layers[Map.BLOCKS][r + 1][c] == 1)){
						//trace(monstersByLevel[level][0].toXMLString());
						layers[Map.ENTITIES][r][c] = convertXMLToObject(c, r, monstersByLevel[level].shift(), Game.g);
					}
				}
				while(chestsByLevel[level].length){
					r = 1 + Math.random() * (bitmap.height - 2);
					c = 1 + Math.random() * (bitmap.width - 2);
					if(layers[Map.ENTITIES][r + 1][c] != MapTileConverter.PIT && !layers[Map.ENTITIES][r][c] && layers[Map.BLOCKS][r][c] != 1 && (bitmap.bitmapData.getPixel32(c, r + 1) == DungeonBitmap.LEDGE || layers[Map.BLOCKS][r + 1][c] == 1)){
						//trace(chestsByLevel[level][0].toXMLString());
						layers[Map.ENTITIES][r][c] = convertXMLToObject(c, r, chestsByLevel[level].shift(), Game.g);
					}
				}
			} else {
				// TO DO!!
				
				
				// content for levels 21+ will have to be generated on the fly
				// the aim is to let the player dig for more random items should they
				// desire to - but they should encounter the level cap on their items
				// and character before long
			}
		}
		
		/* This method tracks down monsters and items and pulls them back into the content manager to be sent out
		 * again if the level is re-visited */
		public function recycleLevel(g:Game):void{
			var i:int;
			var level:int = g.dungeon.level - 1;
			// first we check the active list of entities
			for(i = 0; i < g.entities.length; i++){
				recycleEntity(g.entities[i], level);
			}
			// now we scour the entities layer of the renderer for more entities to convert to XML
			var r:int, c:int;
			for(r = 0; r < g.renderer.height; r++){
				for(c = 0; c < g.renderer.width; c++){
					if(g.renderer.mapArrayLayers[Map.ENTITIES][r][c] is Entity){
						recycleEntity(g.renderer.mapArrayLayers[Map.ENTITIES][r][c], level);
					}
				}
			}
			//trace("recycling..." + g.dungeon.level);
			//for(i = 0; i < monstersByLevel[level].length; i++){
				//trace(monstersByLevel[level][i].toXMLString());
			//}
			//for(i = 0; i < chestsByLevel[level].length; i++){
				//trace(chestsByLevel[level][i].toXMLString());
			//}
		}
		
		/* Used in concert with the recycleLevel() method to convert level assets to XML and store them */
		public function recycleEntity(entity:Entity, level:int):void{
			var chest:XML;
			if(entity is Monster){
				monstersByLevel[level].push(entity.toXML());
			} else if(entity is Item){
				if(chestsByLevel[level].length > 0){
					chest = chestsByLevel[level][chestsByLevel[level].length - 1];
					if(chest.item.length < 1 + Math.random() * 3){
						chest.appendChild(entity.toXML());
					} else {
						chest = <chest />;
						chest.appendChild(entity.toXML());
						chestsByLevel[level].push(chest);
					}
				} else {
					chest = <chest />;
					chest.appendChild(entity.toXML());
					chestsByLevel[level].push(chest);
				}
			} else if(entity is Chest){
				chest = entity.toXML();
				if(chest) chestsByLevel[level].push(entity.toXML());
			}
		}
		
		/* Create a random character appropriate for the dungeon level */
		public static function createCharacterXML(dungeonLevel:int, type:int):XML{
			var characterXML:XML = <character />;
			var name:int = Math.random() * CharacterAttributes.NAME_STRINGS.length;
			var level:int = -1 + Math.random() * dungeonLevel;
			if(type == Character.MONSTER){
				while(name < 2 || name > dungeonLevel + 1){
					name = Math.random() * CharacterAttributes.NAME_STRINGS.length;
					if(name > dungeonLevel + 1) name = dungeonLevel + 1;
				}
			}
			characterXML.@name = name;
			characterXML.@type = type;
			characterXML.@level = level;
			return characterXML;
		}
		
		/* Create a random item appropriate for the dungeon level */
		public static function createItemXML(dungeonLevel:int, type:int):XML{
			var itemXML:XML = <item />;
			var enchantments:int = -2 + Math.random() * dungeonLevel;
			var name:int;
			var level:int =  1 + Math.random() * dungeonLevel;
			var nameRange:int;
			if(type == Item.ARMOUR){
				nameRange = Item.ARMOUR_NAMES.length;
			} else if(type == Item.WEAPON){
				nameRange = Item.WEAPON_NAMES.length;
			} else if(type == Item.RUNE){
				nameRange = Item.RUNE_NAMES.length;
				level = 0;
				enchantments = 0;
			}
			if(nameRange > dungeonLevel) nameRange = dungeonLevel;
			name = Math.random() * nameRange;
			
			itemXML.@name = name;
			itemXML.@type = type;
			itemXML.@level = level;
			if(enchantments > 0){
				var runeList:Vector.<int> = new Vector.<int>();
				while(enchantments--){
					nameRange = Math.random() * Item.RUNE_NAMES.length;
					if(nameRange > dungeonLevel) nameRange = dungeonLevel;
					name = Math.random() * nameRange;
					runeList.push(name);
				}
				// each effect must now be given a level, for this we do a bucket sort
				// to stack the effects
				var bucket:Vector.<int> = new Vector.<int>(Item.RUNE_NAMES.length);
				var i:int;
				for(i = 0; i < runeList.length; i++){
					bucket[runeList[i]]++;
				}
				for(i = 0; i < bucket.length; i++){
					if(bucket[i]){
						var effectXML:XML = <effect />;
						effectXML.@name = i;
						effectXML.@level = bucket[i];
						itemXML.appendChild(effectXML);
					}
				}
			}
			return itemXML;
		}
		
		public static function convertXMLToObject(x:int, y:int, xml:XML, g:Game):*{
			var objectType:String = xml.name();
			var i:int, children:XMLList, item:XML, mc:DisplayObject, obj:*;
			var name:int, level:int, type:int;
			var className:Class;
			var items:Vector.<Item>;
			if(objectType == "chest"){
				children = xml.children();
				items = new Vector.<Item>();
				for each(item in children){
					items.push(convertXMLToObject(x, y, item, g));
				}
				mc = new g.library.ChestMC();
				mc.x = x * Game.SCALE + Game.SCALE * 0.5;
				mc.y = (y + 1) * Game.SCALE;
				obj = new Chest(mc, items, g);
				obj.holder = g.itemsHolder;
			} else if(objectType == "item"){
				name = xml.@name;
				level = xml.@level;
				type = xml.@type;
				if(type == Item.RUNE){
					mc = new g.library.RuneMC();
				} else if(type == Item.ARMOUR){
					className = g.library.armourNameToMCClass(name);
					mc = new className();
				} else if(type == Item.WEAPON){
					className = g.library.weaponNameToMCClass(name);
					mc = new className();
				}
				obj = new Item(mc, name, type, level, g);
				obj.holder = g.itemsHolder;
				
				// is this item enchanted?
				var effect:Effect;
				for each(var enchantment:XML in xml.effect){
					effect = new Effect(enchantment.@name, enchantment.@level, 0, g);
					effect.enchant(obj);
				}
			} else if(objectType == "character"){
				name = xml.@name;
				level = xml.@level;
				type = xml.@type;
				if(xml.item.length()){
					items = new Vector.<Item>();
					for each(item in xml.item){
						items.push(convertXMLToObject(x, y, item, g));
					}
				}
				if(type == Character.MONSTER){
					className = g.library.characterNameToMcClass(name);
					mc = new className();
					mc.x = x * Game.SCALE + Game.SCALE * 0.5;
					mc.y = y * Game.SCALE + (Game.SCALE - mc.height * 0.5);
					obj = new Monster(mc, name, level, items, mc.width, mc.height, g);
					obj.holder = g.entitiesHolder;
				}
			}
			obj.layer = Map.ENTITIES;
			return obj;
		}
		
	}

}