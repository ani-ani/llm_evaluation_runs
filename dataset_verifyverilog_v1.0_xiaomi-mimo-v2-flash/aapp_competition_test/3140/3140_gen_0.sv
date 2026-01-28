module FishCatchCount(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid_t [0:63],
    output reg [15:0] result,
    output reg done
);

    // Parameters
    localparam [7:0] GRID_SIZE = 8'd64;
    localparam [7:0] MAX_TIME = 8'd128;
    localparam [7:0] K = 8'd5;
    localparam [7:0] START_TIME = 8'd1;
    localparam [7:0] START_POS = 8'd0;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RESET_STATE = 3'd1;
    localparam [2:0] COMPUTE_INIT = 3'd2;
    localparam [2:0] COMPUTE_TIME = 3'd3;
    localparam [2:0] CHECK_CELLS = 3'd4;
    localparam [2:0] UPDATE_REACH = 3'd5;
    localparam [2:0] FINISH = 3'd6;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] time_counter;
    reg [7:0] cell_counter;
    reg [63:0] reachable_current;
    reg [63:0] reachable_next;
    reg [15:0] result_reg;
    
    // Combinational logic for neighbor checking
    wire [7:0] row, col;
    wire [7:0] north_cell, south_cell, east_cell, west_cell;
    wire north_valid, south_valid, east_valid, west_valid;
    wire north_reachable, south_reachable, east_reachable, west_reachable;
    wire [63:0] next_reachable_mask;
    
    // Helper signals for time window check
    wire [7:0] appear_time;
    wire [7:0] end_time;
    wire time_in_window;
    
    // Row/col calculation from cell index
    assign row = cell_counter >> 3;  // row = cell / 8
    assign col = cell_counter & 8'h07;  // col = cell % 8
    
    // Neighbor cell calculations
    assign north_cell = (row > 8'd0) ? (cell_counter - 8'd8) : 8'd255;
    assign south_cell = (row < 8'd7) ? (cell_counter + 8'd8) : 8'd255;
    assign east_cell = (col < 8'd7) ? (cell_counter + 8'd1) : 8'd255;
    assign west_cell = (col > 8'd0) ? (cell_counter - 8'd1) : 8'd255;
    
    // Neighbor validity flags
    assign north_valid = (row > 8'd0);
    assign south_valid = (row < 8'd7);
    assign east_valid = (col < 8'd7);
    assign west_valid = (col > 8'd0);
    
    // Neighbor reachable status
    assign north_reachable = north_valid ? reachable_current[north_cell] : 1'b0;
    assign south_reachable = south_valid ? reachable_current[south_cell] : 1'b0;
    assign east_reachable = east_valid ? reachable_current[east_cell] : 1'b0;
    assign west_reachable = west_valid ? reachable_current[west_cell] : 1'b0;
    
    // Next reachable mask for current cell
    assign next_reachable_mask = (north_reachable | south_reachable | east_reachable | west_reachable) ? (64'd1 << cell_counter) : 64'd0;
    
    // Time window check
    assign appear_time = grid_t[cell_counter];
    assign end_time = appear_time + K;
    assign time_in_window = (time_counter >= appear_time) && (time_counter < end_time);
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? RESET_STATE : IDLE;
            RESET_STATE: next_state = COMPUTE_INIT;
            COMPUTE_INIT: next_state = COMPUTE_TIME;
            COMPUTE_TIME: next_state = CHECK_CELLS;
            CHECK_CELLS: next_state = (cell_counter < GRID_SIZE) ? CHECK_CELLS : UPDATE_REACH;
            UPDATE_REACH: next_state = (time_counter < MAX_TIME) ? COMPUTE_TIME : FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            time_counter <= 8'd0;
            cell_counter <= 8'd0;
            reachable_current <= 64'd0;
            reachable_next <= 64'd0;
            result_reg <= 16'd0;
            done <= 1'b0;
            result <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                RESET_STATE: begin
                    time_counter <= 8'd0;
                    cell_counter <= 8'd0;
                    reachable_current <= 64'd0;
                    reachable_next <= 64'd0;
                    result_reg <= 16'd0;
                    done <= 1'b0;
                    result <= 16'd0;
                end
                
                COMPUTE_INIT: begin
                    // Initialize at START_TIME from START_POS
                    if (START_TIME == 8'd1) begin
                        reachable_current <= 64'd1 << START_POS;
                        time_counter <= START_TIME;
                    end
                end
                
                COMPUTE_TIME: begin
                    reachable_next <= 64'd0;
                    cell_counter <= 8'd0;
                end
                
                CHECK_CELLS: begin
                    // Update cell counter for next iteration
                    cell_counter <= cell_counter + 8'd1;
                    
                    // Check if current cell should be in next reachable set
                    if (cell_counter < GRID_SIZE) begin
                        if (next_reachable_mask != 64'd0) begin
                            reachable_next <= reachable_next | next_reachable_mask;
                        end
                        
                        // Check fish eligibility
                        if (reachable_current[cell_counter] && time_in_window) begin
                            result_reg <= result_reg + 16'd1;
                        end
                    end
                end
                
                UPDATE_REACH: begin
                    reachable_current <= reachable_next;
                    time_counter <= time_counter + 8'd1;
                end
                
                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    // Handle IDLE state
                    done <= 1'b0;
                end
            endcase
            
            // Clear done signal after it's been high for one cycle
            if (done && state != FINISH) begin
                done <= 1'b0;
            end
        end
    end
    
endmodule