module vacation_dp(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] day_arr [0:99],
    input wire [6:0] n,
    output reg [7:0] result,
    output reg done,
    output reg busy
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    // FSM state and counters
    reg [1:0] state, next_state;
    reg [6:0] day_counter;  // 0 to n-1
    reg [6:0] n_reg;  // Store n after start
    
    // DP states (rest, contest, sport) for current day
    reg [7:0] dp_rest;
    reg [7:0] dp_contest;
    reg [7:0] dp_sport;
    
    // Previous DP states (for update)
    reg [7:0] prev_dp_rest;
    reg [7:0] prev_dp_contest;
    reg [7:0] prev_dp_sport;
    
    // Current day input
    reg [1:0] current_day;
    
    // Combinational logic for next DP values
    wire [7:0] next_dp_rest;
    wire [7:0] next_dp_contest;
    wire [7:0] next_dp_sport;
    
    wire [7:0] min_prev_rest_contest;
    wire [7:0] min_prev_rest_sport;
    wire [7:0] min_prev_all;
    
    // Helper wires for min operations
    wire [7:0] min_1;
    wire [7:0] min_2;
    wire [7:0] min_3;
    
    // Infinity constant
    localparam [7:0] INF = 8'd255;
    
    // Combinational min logic (3-input minimum)
    assign min_1 = (prev_dp_rest < prev_dp_contest) ? prev_dp_rest : prev_dp_contest;
    assign min_prev_rest_contest = min_1;
    
    assign min_2 = (prev_dp_rest < prev_dp_sport) ? prev_dp_rest : prev_dp_sport;
    assign min_prev_rest_sport = min_2;
    
    assign min_3 = (prev_dp_contest < prev_dp_sport) ? prev_dp_contest : prev_dp_sport;
    wire [7:0] min_prev_1_2;
    assign min_prev_1_2 = (prev_dp_rest < min_3) ? prev_dp_rest : min_3;
    assign min_prev_all = min_prev_1_2;
    
    // Calculate next DP values
    // Rest: min of all previous + 1
    assign next_dp_rest = min_prev_all + 8'd1;
    
    // Contest: min(rest, sport) if available, else INF
    wire contest_available;
    assign contest_available = current_day[0];  // Bit 0 (contest)
    assign next_dp_contest = contest_available ? min_prev_rest_sport : INF;
    
    // Sport: min(rest, contest) if available, else INF
    wire sport_available;
    assign sport_available = current_day[1];  // Bit 1 (gym)
    assign next_dp_sport = sport_available ? min_prev_rest_contest : INF;
    
    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            day_counter <= 7'd0;
            n_reg <= 7'd0;
            dp_rest <= 8'd0;
            dp_contest <= 8'd0;
            dp_sport <= 8'd0;
            prev_dp_rest <= 8'd0;
            prev_dp_contest <= 8'd0;
            prev_dp_sport <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            current_day <= 2'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        day_counter <= 7'd0;
                        // Initialize DP for day 0 (no activity yet, 0 rest days)
                        dp_rest <= 8'd0;
                        dp_contest <= 8'd0;
                        dp_sport <= 8'd0;
                        prev_dp_rest <= 8'd0;
                        prev_dp_contest <= 8'd0;
                        prev_dp_sport <= 8'd0;
                        // Load first day's data (if n > 0)
                        if (n > 0) begin
                            current_day <= day_arr[0];
                        end
                    end
                end
                
                LOAD: begin
                    // Continue loading (already loaded in IDLE)
                    // This state allows for loading multiple days if needed
                end
                
                PROCESS: begin
                    // Update DP registers with computed next values
                    dp_rest <= next_dp_rest;
                    dp_contest <= next_dp_contest;
                    dp_sport <= next_dp_sport;
                    
                    // Update previous for next iteration
                    prev_dp_rest <= next_dp_rest;
                    prev_dp_contest <= next_dp_contest;
                    prev_dp_sport <= next_dp_sport;
                    
                    // Increment day counter
                    day_counter <= day_counter + 7'd1;
                    
                    // Load next day's data if not at end
                    if (day_counter + 7'd1 < n_reg) begin
                        current_day <= day_arr[day_counter + 7'd1];
                    end
                end
                
                DONE: begin
                    // Compute final result as min of three states
                    result <= (dp_rest < dp_contest) ? 
                             ((dp_rest < dp_sport) ? dp_rest : dp_sport) :
                             ((dp_contest < dp_sport) ? dp_contest : dp_sport);
                    done <= 1'b1;
                    busy <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && n > 7'd0) begin
                    next_state = PROCESS;
                end else if (start && n == 7'd0) begin
                    next_state = DONE;  // Edge case: 0 days
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                next_state = PROCESS;  // Skip load, go directly to process
            end
            
            PROCESS: begin
                if (day_counter + 7'd1 >= n_reg) begin
                    next_state = DONE;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            DONE: begin
                next_state = IDLE;  // Auto-return to idle after 1 cycle
            end
            
            default: next_state = IDLE;
        endcase
    end
    
endmodule