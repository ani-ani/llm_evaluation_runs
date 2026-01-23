module max_bling_calculator(
    input clk, rst_n, start,
    input [7:0] d_in, b_in, f_in, t0_in, t1_in, t2_in,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam SIMULATE_DAY = 2'b01;
    localparam CALCULATE = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] state, next_state;
    
    // Internal registers for simulation state
    reg [7:0] days_left;
    reg [15:0] bling;
    reg [7:0] fruits;
    reg [7:0] exotic_fruits;
    reg [7:0] t0, t1, t2;
    reg [7:0] et0, et1, et2; // Exotic trees

    // Combinational logic for next state
    always @(*) begin
        case (state)
            IDLE: next_state = start ? SIMULATE_DAY : IDLE;
            SIMULATE_DAY: next_state = CALCULATE;
            CALCULATE: next_state = (days_left == 0) ? DONE_STATE : SIMULATE_DAY;
            DONE_STATE: next_state = DONE_STATE;
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            // Reset all internal state
            days_left <= 0;
            bling <= 0;
            fruits <= 0;
            exotic_fruits <= 0;
            t0 <= 0; t1 <= 0; t2 <= 0;
            et0 <= 0; et1 <= 0; et2 <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Load inputs
                        days_left <= d_in;
                        bling <= {8'b0, b_in}; // Zero extend to 16-bit
                        fruits <= f_in;
                        exotic_fruits <= 0; // No exotic fruits initially
                        t0 <= t0_in;
                        t1 <= t1_in;
                        t2 <= t2_in;
                        et0 <= 0;
                        et1 <= 0;
                        et2 <= 0;
                        done <= 0;
                    end
                end
                
                SIMULATE_DAY: begin
                    // 1. Harvest Trees
                    // Normal trees (t0) yield 3 fruits each
                    // Exotic trees (et0) yield 3 exotic fruits each
                    // We calculate intermediate values first
                    
                    // 2. Action Logic
                    if (days_left >= 3) begin
                        // Strategy: Plant normal fruits, Buy exotic fruits to plant
                        
                        // Plant normal fruits
                        // Harvest adds to fruits, then we plant them all
                        // So new t2 adds: current t2 + (current fruits + 3*t0)
                        t2 <= t2 + fruits + (t0 * 3);
                        fruits <= 0;
                        
                        // Buy Exotic (Plant immediately)
                        // Check current Bling (before any sales/other income)
                        if (bling >= 400) begin
                            bling <= bling - 400;
                            et2 <= et2 + 1; // New exotic tree planted
                        end
                        
                        // Carry over exotic fruits from harvest (if any), but don't sell
                        // (Strategy implies planting exotic fruits, but if we don't buy, we don't plant exotic. 
                        // Existing exotic trees yield fruits. Do we keep them?
                        // Prompt: "Plant/Sell fruits?". 
                        // If days >= 3, we plant normal. It doesn't explicitly say we plant exotic fruits harvested.
                        // Usually, if we have exotic fruits, we can't plant them without buying? 
                        // "Buy exotic? ... plant immediately". 
                        // It implies buying is the action. 
                        // If we harvest exotic fruits (from existing trees), they are just fruits.
                        // Prompt says "Exotic fruits cost 400...". It doesn't say "Exotic fruits can be planted for free".
                        // So if we harvest exotic fruits, we probably sell them if days < 3.
                        // If days >= 3, do we plant them? 
                        // "Plant/Sell fruits?". "Normal fruits sell for 100, plant into trees."
                        // "Exotic fruits cost 400...". 
                        // Usually you only plant normal fruits. Exotic is a buy/sell or buy/plant commodity.
                        // If we harvest exotic fruits, we likely keep them (if days >= 3) to plant later? 
                        // Or sell immediately? The prompt is silent on planting harvested exotic fruits.
                        // Let's assume harvested exotic fruits are kept if days >= 3, sold if < 3.
                        // Wait, "Action: Buy exotic? ... Plant immediately". 
                        // "Action: Plant/Sell fruits?" -> "If remaining days >= 3, plant normal fruits."
                        // This is specific to normal fruits.
                        // So, harvested exotic fruits are treated as "fruits" in the general sense?
                        // "Exotic fruits cost 400... sell for 500". 
                        // If we have them (harvested), we likely just carry them over (or sell if < 3).
                        // If days >= 3, do we plant them? Usually not, unless specified.
                        // Let's default to: If days >= 3, we only buy exotic to plant. 
                        // We do not plant harvested exotic fruits.
                        // We keep harvested exotic fruits in `exotic_fruits`.
                        // We do not sell them.
                        // So `exotic_fruits` accumulates if we have exotic trees and days >= 3.
                        // If days < 3, we sell all `exotic_fruits`.
                        
                        exotic_fruits <= exotic_fruits + (et0 * 3);
                        
                    end else begin // days_left < 3
                        // Strategy: Sell everything, Buy exotic to flip
                        
                        // Harvest adds to fruits/exotic_fruits
                        // Sell Normal Fruits
                        // Total normal fruits to sell: current fruits + harvest
                        bling <= bling + (fruits * 100) + (t0 * 3 * 100);
                        fruits <= 0;
                        
                        // Sell Exotic Fruits (accumulated + harvest)
                        // Total exotic fruits to sell: current exotic_fruits + harvest
                        bling <= bling + (fruits * 100) + (t0 * 3 * 100) + (exotic_fruits * 500) + (et0 * 3 * 500);
                        exotic_fruits <= 0;
                        
                        // Buy & Sell Exotic (Flip)
                        // Check if we can buy (using money after selling normal fruits)
                        // Let's calculate the money after selling normal fruits
                        // Temp logic: 
                        // Money after normal sell = bling + (fruits + t0*3)*100
                        // If that >= 400, we can flip.
                        // Net profit = 100.
                        if (bling + (fruits * 100) + (t0 * 3 * 100) >= 400) begin
                            bling <= bling + (fruits * 100) + (t0 * 3 * 100) + (exotic_fruits * 500) + (et0 * 3 * 500) + 100;
                        end else begin
                            bling <= bling + (fruits * 100) + (t0 * 3 * 100) + (exotic_fruits * 500) + (et0 * 3 * 500);
                        end
                        
                        // No new exotic trees planted
                        exotic_fruits <= 0;
                    end
                    
                    // 3. Update Trees (Shift Register)
                    // Normal Trees
                    t0 <= t1;
                    t1 <= t2;
                    // t2 is updated in logic above. If not updated, it resets? No, it carries over.
                    // In >=3 case, we added to t2. In <3 case, we didn't.
                    // Wait, shift register logic:
                    // New t2 = (what was planted today).
                    // So we need to update t2 separately.
                    // The code above `t2 <= t2 + fruits...` handles the new planting.
                    // But we also need to shift the existing ones.
                    // So: `t2_new` = `t2` (old) + `new_planted`.
                    // `t1_new` = `t2_old`.
                    // `t0_new` = `t1_old`.
                    // We need to be careful with order or use temp variables.
                    // Let's use temp variables for shift logic.
                    
                    // -- Revision for SIMULATE_DAY --
                    // It is a single clock edge. We update all regs based on current values.
                    // We can use intermediate values.
                    
                    // Harvest
                    // new_fruits = fruits + (t0 * 3)
                    // new_exotic = exotic_fruits + (et0 * 3)
                    
                    // Action
                    // if (days >= 3):
                    //   plant_normal = new_fruits
                    //   new_t2 = t2 + plant_normal
                    //   new_fruits = 0
                    //   if (bling >= 400): buy_exotic = 1, new_bling = bling - 400, new_et2 = et2 + 1
                    //   new_exotic = new_exotic (keep)
                    // else:
                    //   sell_normal = new_fruits * 100
                    //   sell_exotic = new_exotic * 500
                    //   new_bling = bling + sell_normal + sell_exotic
                    //   if (new_bling >= 400): new_bling += 100 (flip)
                    //   new_fruits = 0, new_exotic = 0
                    //   new_t2 = t2 (no new planting)
                    //   new_et2 = et2 (no new planting)
                    
                    // Shift
                    // new_t0 = t1
                    // new_t1 = t2
                    // new_et0 = et1
                    // new_et1 = et2
                    // (Note: new_t2/new_et2 already calculated above)
                    
                    // Decrement Days
                    // new_days = days_left - 1
                    
                    // Assign to registers
                    
                    // Implementing in place:
                    
                    // Harvest Step
                    fruits <= fruits + (t0 * 3);
                    exotic_fruits <= exotic_fruits + (et0 * 3);
                    
                    // We need to act on the HARVESTED amount.
                    // But the procedural assignment `fruits <= fruits + (t0 * 3)` updates `fruits`.
                    // We can use the result of the addition.
                    // Let's use combinational logic inside the block or helper wires? 
                    // Since this is a clocked block, we can calculate next values and assign.
                    
                    // Let's define local variables for calculation.
                    // Note: In Verilog 2001, local variables in procedural block are okay if declared as 'reg' or 'integer' outside.
                    // But to keep it simple, let's use the registers themselves for intermediate steps, carefully.
                    
                    // Actually, to avoid race conditions, we should calculate using `current` values.
                    // But we are updating the registers directly.
                    
                    // Let's use a different approach. Calculate next values based on state before update.
                    // But we are in a clocked block. We can't read the updated value in the same cycle.
                    // We need to read the OLD values.
                    
                    // So, inside `SIMULATE_DAY`:
                    reg [15:0] new_bling;
                    reg [7:0] new_fruits;
                    reg [7:0] new_exotic;
                    reg [7:0] new_t2;
                    reg [7:0] new_et2;
                    
                    new_fruits = fruits + (t0 * 3);
                    new_exotic = exotic_fruits + (et0 * 3);
                    
                    if (days_left >= 3) begin
                        new_t2 = t2 + new_fruits;
                        new_fruits = 0;
                        new_et2 = et2;
                        new_bling = bling;
                        if (bling >= 400) begin
                            new_bling = bling - 400;
                            new_et2 = et2 + 1;
                        end
                        // Keep exotic fruits? Yes.
                    end else begin
                        // Sell
                        new_bling = bling + (new_fruits * 100) + (new_exotic * 500);
                        if (new_bling >= 400) new_bling = new_bling + 100;
                        new_fruits = 0;
                        new_exotic = 0;
                        new_t2 = t2;
                        new_et2 = et2;
                    end
                    
                    // Shift
                    t0 <= t1;
                    t1 <= t2;
                    t2 <= new_t2;
                    et0 <= et1;
                    et1 <= et2;
                    et2 <= new_et2;
                    
                    // Update others
                    bling <= new_bling;
                    fruits <= new_fruits;
                    exotic_fruits <= new_exotic;
                    days_left <= days_left - 1;
                end
                
                CALCULATE: begin
                    // Final result is the bling amount
                    result <= bling;
                    done <= 1;
                    // State will transition to DONE_STATE
                end
                
                DONE_STATE: begin
                    // Keep done high
                    done <= 1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule