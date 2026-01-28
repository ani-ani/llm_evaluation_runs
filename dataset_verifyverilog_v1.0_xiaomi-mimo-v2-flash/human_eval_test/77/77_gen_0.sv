module perfect_cube (
    input clk,
    input rst_n,
    input start,
    input signed [7:0] a,
    output reg is_cube,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_CANDIDATE = 3'd1;
    localparam [2:0] CALC_CUBE = 3'd2;
    localparam [2:0] CHECK_MATCH = 3'd3;
    localparam [2:0] INCREMENT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg signed [7:0] n;           // Current candidate root
    reg signed [15:0] n_sq;       // n squared (intermediate)
    reg signed [15:0] n_cubed;    // n cubed (result)
    reg match_found;              // Match flag
    reg [3:0] iteration_count;    // Prevent infinite loops (max 11)
    localparam [3:0] MAX_ITER = 4'd11;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            is_cube <= 1'b0;
            done <= 1'b0;
            n <= 8'sd0;
            n_sq <= 16'sd0;
            n_cubed <= 16'sd0;
            match_found <= 1'b0;
            iteration_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    match_found <= 1'b0;
                    iteration_count <= 4'd0;
                    if (start) begin
                        n <= -8'sd5;  // Start with n = -5
                    end
                end
                
                LOAD_CANDIDATE: begin
                    // n is already loaded from previous state
                end
                
                CALC_CUBE: begin
                    // n * n = n_sq (signed 8x8 = 16-bit)
                    n_sq <= n * n;
                end
                
                CHECK_MATCH: begin
                    // n_cubed = n_sq * n (signed 16x8 = 24-bit, truncate to 16)
                    n_cubed <= n_sq * n;
                    
                    // Check if n_cubed matches a
                    if (n_sq * n == a) begin
                        match_found <= 1'b1;
                    end
                end
                
                INCREMENT: begin
                    if (!match_found && iteration_count < MAX_ITER) begin
                        n <= n + 8'sd1;  // Increment candidate
                        iteration_count <= iteration_count + 4'd1;
                    end
                end
                
                FINISH: begin
                    is_cube <= match_found;
                    done <= 1'b1;
                    n <= 8'sd0;
                    n_sq <= 16'sd0;
                    n_cubed <= 16'sd0;
                    match_found <= 1'b0;
                    iteration_count <= 4'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD_CANDIDATE;
            end
            
            LOAD_CANDIDATE: begin
                next_state = CALC_CUBE;
            end
            
            CALC_CUBE: begin
                next_state = CHECK_MATCH;
            end
            
            CHECK_MATCH: begin
                next_state = INCREMENT;
            end
            
            INCREMENT: begin
                if (match_found || iteration_count >= MAX_ITER) begin
                    next_state = FINISH;
                end else begin
                    next_state = LOAD_CANDIDATE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule