module largest_connected_component(
    input clk,
    input rst_n,
    input start,
    input [7:0] h_0_0, input [7:0] h_0_1, input [7:0] h_0_2, input [7:0] h_0_3,
    input [7:0] h_1_0, input [7:0] h_1_1, input [7:0] h_1_2, input [7:0] h_1_3,
    input [7:0] h_2_0, input [7:0] h_2_1, input [7:0] h_2_2, input [7:0] h_2_3,
    input [7:0] h_3_0, input [7:0] h_3_1, input [7:0] h_3_2, input [7:0] h_3_3,
    input [7:0] v_0_0, input [7:0] v_0_1, input [7:0] v_0_2, input [7:0] v_0_3,
    input [7:0] v_1_0, input [7:0] v_1_1, input [7:0] v_1_2, input [7:0] v_1_3,
    input [7:0] v_2_0, input [7:0] v_2_1, input [7:0] v_2_2, input [7:0] v_2_3,
    input [7:0] v_3_0, input [7:0] v_3_1, input [7:0] v_3_2, input [7:0] v_3_3,
    output reg [7:0] max_size,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_S = 3'd1;
    localparam [2:0] FLOOD_FILL = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Grid storage for s values
    reg [8:0] s [0:3][0:3];
    reg [7:0] current_max_size;
    reg [7:0] current_size;
    reg [8:0] target_s;
    reg [1:0] stack_ptr;
    reg [1:0] stack_x [0:15];
    reg [1:0] stack_y [0:15];
    reg [1:0] current_x;
    reg [1:0] current_y;
    reg [3:0] i, j;
    reg [3:0] x, y;
    reg [3:0] k;
    reg [3:0] visited [0:3][0:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_size <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_max_size <= 8'd0;
            current_size <= 8'd0;
            target_s <= 9'd0;
            stack_ptr <= 2'd0;
            current_x <= 2'd0;
            current_y <= 2'd0;
            i <= 4'd0;
            j <= 4'd0;
            x <= 4'd0;
            y <= 4'd0;
            k <= 4'd0;
            for (x = 0; x < 4; x = x + 1) begin
                for (y = 0; y < 4; y = y + 1) begin
                    s[x][y] <= 9'd0;
                    visited[x][y] <= 4'd0;
                end
            end
            for (k = 0; k < 16; k = k + 1) begin
                stack_x[k] <= 2'd0;
                stack_y[k] <= 2'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_S;
                    end
                end
                
                COMPUTE_S: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count == 8'd1) begin
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                    if (i < 4) begin
                        if (j < 4) begin
                            case (i)
                                4'd0: case (j)
                                    4'd0: s[i][j] <= h_0_0 + v_0_0;
                                    4'd1: s[i][j] <= h_0_1 + v_0_1;
                                    4'd2: s[i][j] <= h_0_2 + v_0_2;
                                    4'd3: s[i][j] <= h_0_3 + v_0_3;
                                endcase
                                4'd1: case (j)
                                    4'd0: s[i][j] <= h_1_0 + v_1_0;
                                    4'd1: s[i][j] <= h_1_1 + v_1_1;
                                    4'd2: s[i][j] <= h_1_2 + v_1_2;
                                    4'd3: s[i][j] <= h_1_3 + v_1_3;
                                endcase
                                4'd2: case (j)
                                    4'd0: s[i][j] <= h_2_0 + v_2_0;
                                    4'd1: s[i][j] <= h_2_1 + v_2_1;
                                    4'd2: s[i][j] <= h_2_2 + v_2_2;
                                    4'd3: s[i][j] <= h_2_3 + v_2_3;
                                endcase
                                4'd3: case (j)
                                    4'd0: s[i][j] <= h_3_0 + v_3_0;
                                    4'd1: s[i][j] <= h_3_1 + v_3_1;
                                    4'd2: s[i][j] <= h_3_2 + v_3_2;
                                    4'd3: s[i][j] <= h_3_3 + v_3_3;
                                endcase
                            endcase
                            j <= j + 4'd1;
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        current_max_size <= 8'd0;
                        for (x = 0; x < 4; x = x + 1) begin
                            for (y = 0; y < 4; y = y + 1) begin
                                visited[x][y] <= 4'd0;
                            end
                        end
                        state <= FLOOD_FILL;
                    end
                end
                
                FLOOD_FILL: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < 4) begin
                        if (j < 4) begin
                            if (visited[i][j] == 4'd0) begin
                                target_s <= s[i][j];
                                current_size <= 8'd0;
                                stack_ptr <= 2'd0;
                                stack_x[0] <= i;
                                stack_y[0] <= j;
                                stack_ptr <= stack_ptr + 2'd1;
                                visited[i][j] <= 4'd1;
                                current_size <= current_size + 8'd1;
                                state <= FLOOD_FILL;
                            end else begin
                                j <= j + 4'd1;
                            end
                        end else begin
                            j <= 4'd0;
                            i <= i + 4'd1;
                        end
                    end else begin
                        if (current_size > current_max_size) begin
                            current_max_size <= current_size;
                        end
                        if (current_max_size > max_size) begin
                            max_size <= current_max_size;
                        end
                        done <= 1'b1;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in main always block
        end else begin
            if (state == FLOOD_FILL) begin
                if (stack_ptr > 2'd0) begin
                    stack_ptr <= stack_ptr - 2'd1;
                    current_x <= stack_x[stack_ptr];
                    current_y <= stack_y[stack_ptr];
                    
                    // Check up
                    if (current_x > 2'd0 && visited[current_x - 2'd1][current_y] == 4'd0 && s[current_x - 2'd1][current_y] == target_s) begin
                        visited[current_x - 2'd1][current_y] <= 4'd1;
                        current_size <= current_size + 8'd1;
                        stack_x[stack_ptr] <= current_x - 2'd1;
                        stack_y[stack_ptr] <= current_y;
                        stack_ptr <= stack_ptr + 2'd1;
                    end
                    
                    // Check down
                    if (current_x < 2'd3 && visited[current_x + 2'd1][current_y] == 4'd0 && s[current_x + 2'd1][current_y] == target_s) begin
                        visited[current_x + 2'd1][current_y] <= 4'd1;
                        current_size <= current_size + 8'd1;
                        stack_x[stack_ptr] <= current_x + 2'd1;
                        stack_y[stack_ptr] <= current_y;
                        stack_ptr <= stack_ptr + 2'd1;
                    end
                    
                    // Check left
                    if (current_y > 2'd0 && visited[current_x][current_y - 2'd1] == 4'd0 && s[current_x][current_y - 2'd1] == target_s) begin
                        visited[current_x][current_y - 2'd1] <= 4'd1;
                        current_size <= current_size + 8'd1;
                        stack_x[stack_ptr] <= current_x;
                        stack_y[stack_ptr] <= current_y - 2'd1;
                        stack_ptr <= stack_ptr + 2'd1;
                    end
                    
                    // Check right
                    if (current_y < 2'd3 && visited[current_x][current_y + 2'd1] == 4'd0 && s[current_x][current_y + 2'd1] == target_s) begin
                        visited[current_x][current_y + 2'd1] <= 4'd1;
                        current_size <= current_size + 8'd1;
                        stack_x[stack_ptr] <= current_x;
                        stack_y[stack_ptr] <= current_y + 2'd1;
                        stack_ptr <= stack_ptr + 2'd1;
                    end
                end else begin
                    if (current_size > current_max_size) begin
                        current_max_size <= current_size;
                    end
                    j <= j + 4'd1;
                end
            end
        end
    end

endmodule