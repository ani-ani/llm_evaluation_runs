module tram_explosions(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid_data,
    output reg [7:0] explosions,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [5:0] current_L_index;
    reg [5:0] current_X_index;
    reg [7:0] min_dist;
    reg [7:0] collision_counter;
    reg [7:0] temp_dist;
    reg [2:0] row_L, col_L;
    reg [2:0] row_X, col_X;
    reg [7:0] diff_row, diff_col;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            explosions <= 8'd0;
            done <= 1'b0;
            current_L_index <= 6'd0;
            current_X_index <= 6'd0;
            min_dist <= 8'd255;
            collision_counter <= 8'd0;
            temp_dist <= 8'd0;
            row_L <= 3'd0;
            col_L <= 3'd0;
            row_X <= 3'd0;
            col_X <= 3'd0;
            diff_row <= 8'd0;
            diff_col <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        current_L_index <= 6'd0;
                        current_X_index <= 6'd0;
                        min_dist <= 8'd255;
                        collision_counter <= 8'd0;
                        explosions <= 8'd0;
                    end
                end

                PROCESS: begin
                    // Extract row and column for current L index
                    row_L <= current_L_index[5:3];
                    col_L <= current_L_index[2:0];

                    // Check if current cell is 'L' (2)
                    if (grid_data[current_L_index*8 +: 8] == 8'd2) begin
                        // Iterate through all X positions
                        if (current_X_index < 6'd64) begin
                            // Extract row and column for current X index
                            row_X <= current_X_index[5:3];
                            col_X <= current_X_index[2:0];

                            // Check if current cell is 'X' (1)
                            if (grid_data[current_X_index*8 +: 8] == 8'd1) begin
                                // Calculate distance
                                diff_row <= row_L - row_X;
                                diff_col <= col_L - col_X;
                                temp_dist <= (diff_row * diff_row) + (diff_col * diff_col);

                                // Update min_dist and collision_counter
                                if (temp_dist < min_dist) begin
                                    min_dist <= temp_dist;
                                    collision_counter <= 8'd1;
                                end else if (temp_dist == min_dist) begin
                                    collision_counter <= collision_counter + 8'd1;
                                end
                            end

                            // Move to next X index
                            current_X_index <= current_X_index + 6'd1;
                        end else begin
                            // Finished checking all X for this L
                            // Check for explosion
                            if (collision_counter > 8'd1) begin
                                explosions <= explosions + 8'd1;
                            end

                            // Reset for next L
                            current_X_index <= 6'd0;
                            min_dist <= 8'd255;
                            collision_counter <= 8'd0;

                            // Move to next L index
                            current_L_index <= current_L_index + 6'd1;

                            // Check if all L positions processed
                            if (current_L_index >= 6'd64) begin
                                state <= DONE_STATE;
                            end
                        end
                    end else begin
                        // Current cell is not 'L', move to next L index
                        current_L_index <= current_L_index + 6'd1;
                        current_X_index <= 6'd0;
                        min_dist <= 8'd255;
                        collision_counter <= 8'd0;

                        // Check if all L positions processed
                        if (current_L_index >= 6'd64) begin
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule