--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.ball = {params.ball}
    self.wasHit = 0
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.level = params.level
    gKeytaken = false
    self.multiball = false
    self.recoverPoints = params.recoverPoints
    self.power = Powerup(0, 0)
    self.pSkin = 0
    self.var = 0
    -- give ball random starting velocity
    self.ball[1].inPlay = true
    self.ball[1].dx = math.random(-200, 200)
    self.ball[1].dy = math.random(-50, -60)
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    self.power:update(dt)

    if self.power.inPlay == false then
        self.multiball = false
    end

    if self.power:collides(self.paddle) then
        if self.pSkin == 9 and self.multiball then
            self.var = 1
            local b = Ball(math.random(1,7))
            local b2 = Ball(math.random(1,7))
            b.x = self.ball[1].x
            b.y = self.ball[1].y
            b.inPlay = true
            b.dx = math.random(-200, 200)
            b.dy = math.random(-50, -60)
            table.insert (self.ball, b)
            b2.x = self.ball[1].x
            b2.y = self.ball[1].y
            b2.inPlay = true
            b2.dx = math.random(-200, 200)
            b2.dy = math.random(-50, -60)
            table.insert (self.ball, b2)
            self.multiball = false
        elseif self.pSkin == 10 then
            gKeytaken = true
        end
        self.power.inPlay = false
    end

    for i, ball in pairs(self.ball) do
        
        ball:update(dt)

        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))
            
            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end

        -- detect collision across all bricks with the ball
        for k, brick in pairs(self.bricks) do

            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then
                -- trigger the brick's hit function, which removes it from play
                self.wasHit = brick:hit()

                if self.wasHit == 1 then
                    if self.power.inPlay == false then
                        self.var = math.random(5)
                        if self.var == 1 then
                            self.pSkin = 9
                            self.multiball = true
                            self.power:spawn(ball.x, ball.y, self.pSkin)
                        elseif self.var == 2 or self.var == 3 then
                            if gKeytaken == false and gLock == true then
                                self.pSkin = 10
                            else
                                self.pSkin = 9
                                self.multiball = true
                            end
                            self.power:spawn(ball.x, ball.y, self.pSkin)
                        end
                        self.var = 0
                    end
                end

                -- add to score
                if brick.lock == false then
                    self.score = self.score + (brick.tier * 200 + brick.color * 25)
                end
                
                if brick.lock == true and gKeytaken == true then
                    self.score = self.score + 1000
                end

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)
                    self.paddle.size = math.min(4, self.paddle.size + 1)
                    -- multiply recover points by 2
                    self.recoverPoints = self.recoverPoints * 2

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()
                    self.paddle.size = 2
                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        ball = ball,
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly 
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8
                
                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then
                    
                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32
                
                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8
                
                -- bottom edge if no X collisions or top collision, last possibility
                else
                    
                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
        -- if ball goes below bounds, revert to serve state and decrease health
        if ball.y >= VIRTUAL_HEIGHT then
            if #self.ball == 1 then
                self.health = self.health - 1
                gSounds['hurt']:play()
        
                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints
                    })
                    self.paddle.size = math.max (1, self.paddle.size - 1)
                end
            else
                table.remove(self.ball, i)
            end
        end

    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    self.power:render()

    if gLock then
        if gKeytaken then
            love.graphics.printf("Key ready", 0, VIRTUAL_HEIGHT - 16, VIRTUAL_WIDTH, 'left')
        elseif gKeytaken == false then
            love.graphics.printf("Key not ready", 0, VIRTUAL_HEIGHT - 16, VIRTUAL_WIDTH, 'left')
        end 
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()
    for i, ball in pairs(self.ball) do
        ball:render()
    end

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'left')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end 
    end

    return true
end