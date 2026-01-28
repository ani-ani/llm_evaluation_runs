module casting_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] l_in,
    input wire [15:0] s_in,
    input wire [4:0] c_rom_addr,
    input wire [15:0] c_rom_data,
    output reg [31:0] profit,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_REVENUE = 3'd1;
    localparam [2:0] CHECK_DUPLICATE = 3'd2;
    localparam [2:0] UPDATE_PROFIT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Grid: 16 levels x 16 counts
    reg [3:0] grid [0:15];
    integer i, j;

    // Current processing variables
    reg [3:0] current_l;
    reg [3:0] current_k;
    reg [3:0] new_k;
    reg [3:0] temp_grid_val;

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Initialize grid on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            profit <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_l <= 4'd0;
            current_k <= 4'd0;
            
            // Initialize grid to all zeros
            for (i = 0; i < 16; i = i + 1) begin
                grid[i] <= 4'd0;
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
                if (start) begin
                    next_state = CALC_REVENUE;
                    current_l = l_in;
                    current_k = 4'd1;
                    cycle_count = 8'd0;
                end
            end
            
            CALC_REVENUE: begin
                next_state = CHECK_DUPLICATE;
            end
            
            CHECK_DUPLICATE: begin
                temp_grid_val = grid[current_l];
                if (temp_grid_val == 4'd0) begin
                    next_state = UPDATE_PROFIT;
                end else begin
                    new_k = temp_grid_val + current_k;
                    if (new_k >= 16'd16) begin
                        new_k = 16'd15;
                    end
                    current_k = 4'd1;
                    if (current_l < 15'd15) begin
                        current_l = current_l + 4'd1;
                        next_state = CALC_REVENUE;
                    end else begin
                        next_state = UPDATE_PROFIT;
                    end
                end
            end
            
            UPDATE_PROFIT: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Profit calculation and grid update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main reset block
        end else begin
            case (state)
                CALC_REVENUE: begin
                    profit <= profit + {{16'd0}, c_rom_data};
                end
                
                CHECK_DUPLICATE: begin
                    temp_grid_val = grid[current_l];
                    if (temp_grid_val == 4'd0) begin
                        grid[current_l] <= current_k;
                    end else begin
                        grid[current_l] <= 4'd0;
                        if (current_l < 15'd15) begin
                            grid[current_l + 4'd1] <= current_k;
                        end
                    end
                end
                
                UPDATE_PROFIT: begin
                    profit <= profit - {{16'd0}, s_in};
                    done <= 1'b1;
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                end
                
                default: ;
            endcase
        end
    end

    // Cycle counter increment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state == CHECK_DUPLICATE) begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

endmodule