module vacation_scheduler(
    input clk,
    input rst_n,
    input start,
    input [1:0] day_data,
    input [6:0] day_index,
    input data_valid,
    output reg [7:0] min_rest_days,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam LOAD = 2'b01;
    localparam COMPUTE = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] state, next_state;
    
    // Day buffer storage (assuming input stream provides data sorted by index 0 to N-1)
    reg [1:0] day_buffer [0:99];
    reg [6:0] load_index;
    reg [6:0] max_index; // Stores the highest valid index received
    reg [6:0] proc_index; // Current processing index
    
    // DP state registers: [rest, contest, sport]
    // These track the MAXIMUM active days achievable ending in that state
    reg [7:0] dp_rest;
    reg [7:0] dp_contest;
    reg [7:0] dp_sport;

    // Next DP state values (computed combinational)
    reg [7:0] next_rest;
    reg [7:0] next_contest;
    reg [7:0] next_sport;

    // State Transition Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: begin
                // Transition to compute when data entry 0 is valid or if we finish loading specific sequence logic
                // Simplified: Wait for start to go low, then transition. 
                // Or, assume we load until data_valid stops or specific condition.
                // Based on prompt: "Use state machine: IDLE -> LOAD -> COMPUTE -> DONE."
                // Let's transition when start signal is released (low) after being high.
                // Better approach for stream processing: Transition when we have processed index 0 validly.
                if (!start && load_index > 0) next_state = COMPUTE;
                else next_state = LOAD;
            end
            COMPUTE: begin
                // Process up to max_index
                if (proc_index > max_index) next_state = DONE_STATE;
                else next_state = COMPUTE;
            end
            DONE_STATE: next_state = IDLE; // Wait for next start
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_index <= 7'b0;
            max_index <= 7'b0;
            proc_index <= 7'b0;
            done <= 1'b0;
            min_rest_days <= 8'b0;
            dp_rest <= 8'b0;
            dp_contest <= 8'b0;
            dp_sport <= 8'b0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    if (start) begin
                        load_index <= 7'b0;
                        proc_index <= 7'b0;
                        done <= 1'b0;
                        // Reset DP states for new computation
                        dp_rest <= 8'b0;
                        dp_contest <= 8'b0;
                        dp_sport <= 8'b0;
                    end
                end

                LOAD: begin
                    if (data_valid) begin
                        day_buffer[load_index] <= day_data;
                        // Keep track of max index to know total days later
                        max_index <= load_index;
                        if (load_index < 7'd99) begin
                            load_index <= load_index + 1;
                        end
                    end
                end

                COMPUTE: begin
                    if (proc_index <= max_index) begin
                        // Apply DP transition logic based on day_buffer[proc_index]
                        // Logic derived from prompt:
                        // dp_rest, dp_contest, dp_sport represent max active days ending in R, C, S
                        
                        // Previous values are current dp_* values
                        // New values calculated next cycle or combinational (here we do sequential for area/timing tradeoff)
                        
                        // We need to compute next values based on current state and input
                        // Let's do combinational calculation before assignment for clarity
                        
                        case (day_buffer[proc_index])
                            2'b00: begin // Must rest
                                // New rest = max(prev_rest, prev_contest, prev_sport)
                                // New contest = 0 (invalid)
                                // New sport = 0 (invalid)
                                // Active days don't increment (it was rest)
                                dp_rest <= (dp_rest > dp_contest) ? ((dp_rest > dp_sport) ? dp_rest : dp_sport) : ((dp_contest > dp_sport) ? dp_contest : dp_sport);
                                dp_contest <= 8'b0;
                                dp_sport <= 8'b0;
                            end
                            2'b01: begin // Rest or Contest
                                // New contest = max(prev_rest, prev_sport) + 1
                                // New rest = max(prev_rest, prev_contest, prev_sport)
                                // New sport = 0
                                begin
                                    reg [7:0] max_rest_sport;
                                    max_rest_sport = (dp_rest > dp_sport) ? dp_rest : dp_sport;
                                    
                                    dp_contest <= max_rest_sport + 1;
                                    dp_rest <= (max_rest_sport > dp_contest) ? max_rest_sport : dp_contest;
                                    dp_sport <= 8'b0;
                                end
                            end
                            2'b10: begin // Rest or Sport
                                // New sport = max(prev_rest, prev_contest) + 1
                                // New rest = max(prev_rest, prev_contest, prev_sport)
                                // New contest = 0
                                begin
                                    reg [7:0] max_rest_contest;
                                    max_rest_contest = (dp_rest > dp_contest) ? dp_rest : dp_contest;
                                    
                                    dp_sport <= max_rest_contest + 1;
                                    dp_rest <= (max_rest_contest > dp_sport) ? max_rest_contest : dp_sport;
                                    dp_contest <= 8'b0;
                                end
                            end
                            2'b11: begin // Rest, Sport, Contest
                                // New contest = max(prev_rest, prev_sport) + 1
                                // New sport = max(prev_rest, prev_contest) + 1
                                // New rest = max(prev_rest, prev_contest, prev_sport)
                                begin
                                    reg [7:0] max_rest_sport;
                                    reg [7:0] max_rest_contest;
                                    reg [7:0] max_prev;
                                    
                                    max_rest_sport = (dp_rest > dp_sport) ? dp_rest : dp_sport;
                                    max_rest_contest = (dp_rest > dp_contest) ? dp_rest : dp_contest;
                                    max_prev = (max_rest_sport > dp_contest) ? max_rest_sport : dp_contest; // actually max of all three
                                    // Simplified max of 3:
                                    reg [7:0] temp_max;
                                    temp_max = dp_rest;
                                    if (dp_contest > temp_max) temp_max = dp_contest;
                                    if (dp_sport > temp_max) temp_max = dp_sport;
                                    
                                    dp_contest <= max_rest_sport + 1;
                                    dp_sport <= max_rest_contest + 1;
                                    dp_rest <= temp_max;
                                end
                            end
                        endcase
                        
                        proc_index <= proc_index + 1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Result = Total Days - Max Active Days
                    // Total Days = max_index + 1 (assuming indices 0 to max_index inclusive)
                    // Max Active Days = max(dp_rest, dp_contest, dp_sport)
                    begin
                        reg [7:0] max_active;
                        reg [7:0] total_days;
                        reg [7:0] temp_max;
                        
                        total_days = max_index + 1;
                        
                        temp_max = dp_rest;
                        if (dp_contest > temp_max) temp_max = dp_contest;
                        if (dp_sport > temp_max) temp_max = dp_sport;
                        max_active = temp_max;
                        
                        min_rest_days <= total_days - max_active;
                    end
                end
            endcase
        end
    end

endmodule
