module baron_munchausen(
    input clk,
    input rst_n,
    input start,
    input [3:0] a,
    output reg [15:0] result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CALCULATE = 3'b001;
    localparam CHECK = 3'b010;
    localparam NEXT = 3'b011;
    localparam FOUND = 3'b100;
    localparam DONE = 3'b101;

    reg [15:0] n;
    reg [19:0] product;
    reg [15:0] sum_n;
    reg [15:0] sum_an;
    reg [4:0] state, next_state;

    // Helper variables for digit sum calculation
    reg [15:0] temp_val;
    reg [15:0] calc_sum;
    reg [3:0] digit;
    reg [4:0] calc_stage; // 0: idle/calc start, 1: loop

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CALCULATE;
                else next_state = IDLE;
            end
            CALCULATE: begin
                // Need 1 cycle to multiply, then start sum logic
                // Actually, we can do mult in combo or seq. Let's assume seq calc takes time.
                // To be efficient, we can pipeline or use a calc state.
                // The prompt says states: IDLE, CALCULATE, CHECK, NEXT, FOUND.
                // We will use CALCULATE to setup sum calculations.
                // Let's use a sub-cycle counter inside CALCULATE or make it take multiple cycles.
                // To meet latency, we can do mult in 1 cycle, and sum in 1 cycle if simple.
                // But standard sum takes multiple cycles for digits.
                // Let's define CALCULATE as the state where we perform operations.
                // We will add a small counter to wait for the digit sum calculation.
                if (calc_stage == 5'd0) next_state = CALCULATE; // Wait state inside CALC
                else if (calc_stage == 5'd1) next_state = CHECK;
                else next_state = CALCULATE;
            end
            CHECK: begin
                if (sum_an * a == sum_n) next_state = FOUND;
                else next_state = NEXT;
            end
            NEXT: begin
                if (n < 16'd9999) next_state = CALCULATE;
                else next_state = DONE;
            end
            FOUND: begin
                next_state = DONE;
            end
            DONE: begin
                next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            calc_stage <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        n <= 16'd0;
                        done <= 1'b0;
                        calc_stage <= 5'd0;
                    end
                end

                CALCULATE: begin
                    // Digit sum logic
                    if (calc_stage == 5'd0) begin
                        // Init Mult
                        product <= a * n;
                        // Init Sum N
                        temp_val <= n;
                        calc_sum <= 16'd0;
                        calc_stage <= 5'd1;
                    end else if (calc_stage == 5'd1) begin
                        // Logic for sum_n
                        if (temp_val > 0) begin
                            digit <= temp_val % 10;
                            temp_val <= temp_val / 10;
                            calc_sum <= calc_sum + (temp_val % 10); // Small error here, need correct order or 2 cycles
                            // Fix logic: 1 cycle is not enough for div/mod in FPGA generally without pipelining, 
                            // but synthesis tools can infer logic. 
                            // Let's use a proper sequential state machine for digit extraction.
                            // Since we want max efficiency, let's just correct the logic.
                            // We need sum_n. We'll do it in 2 stages: Extract N, then Extract Product.
                            // Let's simplify: Use a separate always block or FSM for digit sum.
                            // Given the constraints, let's make CALCULATE take multiple cycles explicitly.
                            // We will restructure slightly to handle the digit sums in loops.
                            // Let's assume 'calc_stage' handles the wait states.
                            // Stage 1: Mult done. Start summing n.
                            // We need to wait for sum_n. 
                            // Let's implement a specialized counter for the digit sum state machine.
                            
                            // RESTARTING DATAPATH LOGIC FOR CLARITY
                            // We will handle sum_n and sum_an sequentially inside CALCULATE state.
                        end
                    end
                end
            endcase
        end
    end

    // RE-IMPLEMENTATION: A cleaner approach for the digit sum which requires multiple cycles
    // State bits: IDLE(0), SUM_N(1), SUM_AN(2), CHECK(3), NEXT(4), FOUND(5), DONE(6)
    // Let's stick to the requested states but implement the sum logic carefully.
    // We need a way to wait. Let's use 'sub_state' or just extend CALCULATE logic.

    // Revised Logic Block
    reg [19:0] p_reg; // Store product
    reg [15:0] n_reg; // Store n
    reg [15:0] sum_n_reg;
    reg [15:0] sum_an_reg;
    reg [2:0] calc_step; // 0: mult, 1: sum_n, 2: sum_an
    
    // Override previous always block for cleaner synthesis
    // We will use a single always block for state transitions and datapath
    // But to handle the sum logic (which is iterative), we need a small counter or FSM within CALCULATE.
    // However, the prompt defines specific states. We must fit logic into them.
    // We can make CALCULATE state last multiple cycles using internal counters.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            n <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            // Internal vars
            calc_stage <= 0;
            sum_n_reg <= 0;
            sum_an_reg <= 0;
            p_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        n <= 16'd0;
                        calc_stage <= 0;
                    end
                end

                CALCULATE: begin
                    // We use calc_stage to count cycles within this state
                    if (calc_stage == 0) begin
                        // Cycle 1: Calculate Product
                        p_reg <= a * n;
                        // Prepare for Sum N (Start N calc next cycle)
                        temp_val <= n;
                        calc_sum <= 0;
                        calc_stage <= 1;
                    end else if (calc_stage <= 16) begin
                        // Cycle 2..17: Sum N (Max 5 digits, but we can be safe and loop)
                        // Actually we can do sequential subtraction or multiplication trick, 
                        // but simple modulus is standard. Since we don't have a clock divider, 
                        // we assume standard logic. 
                        // Note: Combinational division/modulo is heavy. 
                        // Let's do: if (temp_val >= 10) subtract 10 and inc sum, else done.
                        // This takes many cycles if we do 1 digit per cycle. 
                        // To fit in 50,000 cycles, we can afford 20 cycles per number.
                        
                        // Optimized Sum Logic (sequential)
                        if (temp_val >= 10) begin
                            temp_val <= temp_val - 10;
                            calc_sum <= calc_sum + 1;
                        end else begin
                            sum_n_reg <= calc_sum + temp_val;
                            // Transition to Sum Product
                            temp_val <= p_reg[15:0]; // Only need low 16 bits for sum (max 89991)
                            calc_sum <= 0;
                            calc_stage <= 17; // Switch to Sum AN phase
                        end
                    end else if (calc_stage <= 32) begin // 17 to 32 cycles for AN sum
                        // Sum AN Logic
                        if (temp_val >= 10) begin
                            temp_val <= temp_val - 10;
                            calc_sum <= calc_sum + 1;
                        end else begin
                            sum_an_reg <= calc_sum + temp_val;
                            calc_stage <= 33; // Done
                        end
                    end
                    // If we are done with calc logic, we stay in CALCULATE state but next_state logic will move us to CHECK
                    // We need to ensure next_state moves when calc_stage indicates done.
                    // We modify the state logic to watch calc_stage.
                end

                CHECK: begin
                    // Evaluate condition
                    // Done with CALCULATE internal steps, reset stage for next time
                    calc_stage <= 0; 
                    // Logic handled in next_state to decide FOUND or NEXT
                end

                NEXT: begin
                    n <= n + 1;
                end

                FOUND: begin
                    result <= n;
                    done <= 1'b1;
                end

                DONE: begin
                    if (state == NEXT && n > 9999) begin // Special case for -1 if needed, handled in IDLE reset or here
                       if (n > 9999) result <= 16'hFFFF; // -1
                       done <= 1'b1;
                    end
                end
            endcase
        end
    end

    // Fixed Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CALCULATE;
                else next_state = IDLE;
            end
            CALCULATE: begin
                // Wait for digit sums to complete (we used calc_stage up to 33)
                if (calc_stage == 33) next_state = CHECK;
                else next_state = CALCULATE;
            end
            CHECK: begin
                if (sum_an_reg * a == sum_n_reg) next_state = FOUND;
                else next_state = NEXT;
            end
            NEXT: begin
                if (n < 9999) next_state = CALCULATE;
                else next_state = DONE;
            end
            FOUND: next_state = DONE;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

endmodule
