module TrafficLightProbability(
    input wire clk,
    input wire rst_n,
    input wire [31:0] Tg,
    input wire [31:0] Ty,
    input wire [31:0] Tr,
    input wire [31:0] obs_t,
    input wire [1:0] obs_c,
    input wire valid_in,
    input wire start_query,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE_PARAMS = 3'd1;
    localparam [2:0] PROCESS_OBS = 3'd2;
    localparam [2:0] QUERY = 3'd3;
    localparam [2:0] CALCULATE = 3'd4;
    localparam [2:0] OUTPUT = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [31:0] cycle_length;
    reg [31:0] total_favorable;
    reg [31:0] total_valid;
    reg [31:0] query_time;
    reg [1:0] query_color;

    // Interval storage (up to 1000 intervals)
    reg [31:0] interval_start [0:999];
    reg [31:0] interval_end [0:999];
    reg [9:0] interval_count;

    // Temporary registers for calculations
    reg [31:0] temp_start;
    reg [31:0] temp_end;
    reg [31:0] temp_interval_start;
    reg [31:0] temp_interval_end;
    reg [31:0] temp_favorable;
    reg [31:0] temp_valid;
    reg [31:0] temp_result;
    reg [31:0] temp_dividend;
    reg [31:0] temp_divisor;
    reg [31:0] temp_quotient;
    reg [31:0] temp_remainder;
    reg [5:0] temp_bit;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_length <= 32'd0;
            total_favorable <= 32'd0;
            total_valid <= 32'd0;
            query_time <= 32'd0;
            query_color <= 2'd0;
            interval_count <= 10'd0;
            result <= 32'd0;
            done <= 1'b0;
            
            // Initialize all intervals
            integer i;
            for (i = 0; i < 1000; i = i + 1) begin
                interval_start[i] <= 32'd0;
                interval_end[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (Tg != 32'd0 || Ty != 32'd0 || Tr != 32'd0) begin
                    next_state = STORE_PARAMS;
                end
            end
            STORE_PARAMS: begin
                next_state = PROCESS_OBS;
            end
            PROCESS_OBS: begin
                if (start_query) begin
                    next_state = QUERY;
                end
            end
            QUERY: begin
                next_state = CALCULATE;
            end
            CALCULATE: begin
                next_state = OUTPUT;
            end
            OUTPUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine reset
        end else begin
            case (state)
                STORE_PARAMS: begin
                    cycle_length <= Tg + Ty + Tr;
                    // Initialize with full cycle interval
                    interval_count <= 10'd1;
                    interval_start[0] <= 32'd0;
                    interval_end[0] <= cycle_length;
                end
                PROCESS_OBS: begin
                    if (valid_in) begin
                        // Calculate observation interval
                        temp_start = 32'd0;
                        temp_end = 32'd0;
                        case (obs_c)
                            2'd0: begin // Green
                                temp_start = obs_t - Tg;
                                temp_end = obs_t;
                            end
                            2'd1: begin // Yellow
                                temp_start = obs_t - Tg - Ty;
                                temp_end = obs_t - Tg;
                            end
                            2'd2: begin // Red
                                temp_start = obs_t - cycle_length;
                                temp_end = obs_t - Tg - Ty;
                            end
                        endcase
                        
                        // Handle wrap-around
                        if (temp_start < 32'd0) begin
                            temp_start = temp_start + cycle_length;
                        end
                        if (temp_end < 32'd0) begin
                            temp_end = temp_end + cycle_length;
                        end
                        
                        // Intersect with existing intervals
                        temp_interval_count = 10'd0;
                        integer i, j;
                        for (i = 0; i < interval_count; i = i + 1) begin
                            // Check for intersection
                            if (interval_end[i] > temp_start && interval_start[i] < temp_end) begin
                                // Calculate intersection
                                temp_interval_start = interval_start[i] > temp_start ? interval_start[i] : temp_start;
                                temp_interval_end = interval_end[i] < temp_end ? interval_end[i] : temp_end;
                                
                                // Store new interval
                                interval_start[temp_interval_count] = temp_interval_start;
                                interval_end[temp_interval_count] = temp_interval_end;
                                temp_interval_count = temp_interval_count + 10'd1;
                            end
                        end
                        
                        // Update interval list
                        interval_count = temp_interval_count;
                    end
                end
                QUERY: begin
                    query_time = obs_t;
                    query_color = obs_c;
                    
                    // Calculate query interval
                    temp_start = 32'd0;
                    temp_end = 32'd0;
                    case (query_color)
                        2'd0: begin // Green
                            temp_start = query_time - Tg;
                            temp_end = query_time;
                        end
                        2'd1: begin // Yellow
                            temp_start = query_time - Tg - Ty;
                            temp_end = query_time - Tg;
                        end
                        2'd2: begin // Red
                            temp_start = query_time - cycle_length;
                            temp_end = query_time - Tg - Ty;
                        end
                    endcase
                    
                    // Handle wrap-around
                    if (temp_start < 32'd0) begin
                        temp_start = temp_start + cycle_length;
                    end
                    if (temp_end < 32'd0) begin
                        temp_end = temp_end + cycle_length;
                    end
                end
                CALCULATE: begin
                    // Calculate total valid length
                    temp_valid = 32'd0;
                    integer i;
                    for (i = 0; i < interval_count; i = i + 1) begin
                        temp_valid = temp_valid + (interval_end[i] - interval_start[i]);
                    end
                    
                    // Calculate favorable length (intersection with query interval)
                    temp_favorable = 32'd0;
                    for (i = 0; i < interval_count; i = i + 1) begin
                        if (interval_end[i] > temp_start && interval_start[i] < temp_end) begin
                            temp_interval_start = interval_start[i] > temp_start ? interval_start[i] : temp_start;
                            temp_interval_end = interval_end[i] < temp_end ? interval_end[i] : temp_end;
                            temp_favorable = temp_favorable + (temp_interval_end - temp_interval_start);
                        end
                    end
                    
                    // Fixed-point division (Q16.16)
                    if (temp_valid != 32'd0) begin
                        temp_dividend = temp_favorable << 16;
                        temp_divisor = temp_valid;
                        temp_quotient = 32'd0;
                        
                        // Iterative division
                        for (temp_bit = 5'd31; temp_bit >= 0; temp_bit = temp_bit - 1) begin
                            temp_remainder = temp_quotient << 1;
                            if (temp_remainder[31] == 1'b0) begin
                                temp_remainder = temp_remainder - temp_divisor;
                            end
                            
                            if (temp_remainder[31] == 1'b0) begin
                                temp_quotient = temp_remainder;
                                temp_quotient[temp_bit] = 1'b1;
                            end
                        end
                        
                        temp_result = temp_quotient;
                    end else begin
                        temp_result = 32'd0;
                    end
                    
                    result = temp_result;
                end
                OUTPUT: begin
                    done = 1'b1;
                end
                default: begin
                    done = 1'b0;
                end
            endcase
        end
    end

endmodule