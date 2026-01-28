module robot_movement (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid_data,
    input wire [31:0] program,
    input wire [5:0] start_pos,
    input wire [3:0] prog_len,
    output reg done,
    output reg [15:0] result
);

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] SIMULATE = 3'd2;
localparam [2:0] CHECK_CYCLE = 3'd3;
localparam [2:0] DONE = 3'd4;

reg [2:0] state;
reg [2:0] next_state;

// Current simulation state
reg [2:0] cur_row;
reg [2:0] cur_col;
reg [2:0] prog_idx;
reg [15:0] step_count;

// Visited states bitmap: 8 rows × 8 cols × 8 prog_idx = 512 bits
reg [511:0] visited_states;

// Cycle detection flag
reg cycle_detected;

// Next state logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: if (start) next_state = INIT;
        INIT: next_state = SIMULATE;
        SIMULATE: begin
            if (step_count >= 16'd512) begin
                next_state = DONE;
            end else if (visited_states[{cur_row, cur_col, prog_idx}]) begin
                next_state = CHECK_CYCLE;
            end else begin
                next_state = SIMULATE;
            end
        end
        CHECK_CYCLE: next_state = DONE;
        DONE: next_state = IDLE;
        default: next_state = IDLE;
    endcase
end

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Initialize and simulate
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        cur_row <= 3'd0;
        cur_col <= 3'd0;
        prog_idx <= 3'd0;
        step_count <= 16'd0;
        visited_states <= 512'd0;
        done <= 1'b0;
        result <= 16'd0;
        cycle_detected <= 1'b0;
    end else begin
        case (state)
            INIT: begin
                cur_row <= start_pos[5:3];
                cur_col <= start_pos[2:0];
                prog_idx <= 3'd0;
                step_count <= 16'd1;
                visited_states <= 512'd0;
                visited_states[{start_pos[5:3], start_pos[2:0], 3'd0}] <= 1'b1;
                done <= 1'b0;
                cycle_detected <= 1'b0;
            end
            
            SIMULATE: begin
                if (!visited_states[{cur_row, cur_col, prog_idx}]) begin
                    visited_states[{cur_row, cur_col, prog_idx}] <= 1'b1;
                    
                    case (prog_idx)
                        3'd0: begin
                            case (program[3:0])
                                4'd0: begin
                                    if (cur_col > 3'd0 && grid_data[{cur_row, cur_col-1'd1}]) begin
                                        cur_col <= cur_col - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd1: begin
                                    if (cur_col < 3'd7 && grid_data[{cur_row, cur_col+1'd1}]) begin
                                        cur_col <= cur_col + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd2: begin
                                    if (cur_row > 3'd0 && grid_data[{cur_row-1'd1, cur_col}]) begin
                                        cur_row <= cur_row - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd3: begin
                                    if (cur_row < 3'd7 && grid_data[{cur_row+1'd1, cur_col}]) begin
                                        cur_row <= cur_row + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                            endcase
                        end
                        3'd1: begin
                            case (program[7:4])
                                4'd0: begin
                                    if (cur_col > 3'd0 && grid_data[{cur_row, cur_col-1'd1}]) begin
                                        cur_col <= cur_col - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd1: begin
                                    if (cur_col < 3'd7 && grid_data[{cur_row, cur_col+1'd1}]) begin
                                        cur_col <= cur_col + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd2: begin
                                    if (cur_row > 3'd0 && grid_data[{cur_row-1'd1, cur_col}]) begin
                                        cur_row <= cur_row - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd3: begin
                                    if (cur_row < 3'd7 && grid_data[{cur_row+1'd1, cur_col}]) begin
                                        cur_row <= cur_row + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                            endcase
                        end
                        3'd2: begin
                            case (program[11:8])
                                4'd0: begin
                                    if (cur_col > 3'd0 && grid_data[{cur_row, cur_col-1'd1}]) begin
                                        cur_col <= cur_col - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd1: begin
                                    if (cur_col < 3'd7 && grid_data[{cur_row, cur_col+1'd1}]) begin
                                        cur_col <= cur_col + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd2: begin
                                    if (cur_row > 3'd0 && grid_data[{cur_row-1'd1, cur_col}]) begin
                                        cur_row <= cur_row - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd3: begin
                                    if (cur_row < 3'd7 && grid_data[{cur_row+1'd1, cur_col}]) begin
                                        cur_row <= cur_row + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                            endcase
                        end
                        3'd3: begin
                            case (program[15:12])
                                4'd0: begin
                                    if (cur_col > 3'd0 && grid_data[{cur_row, cur_col-1'd1}]) begin
                                        cur_col <= cur_col - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd1: begin
                                    if (cur_col < 3'd7 && grid_data[{cur_row, cur_col+1'd1}]) begin
                                        cur_col <= cur_col + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd2: begin
                                    if (cur_row > 3'd0 && grid_data[{cur_row-1'd1, cur_col}]) begin
                                        cur_row <= cur_row - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd3: begin
                                    if (cur_row < 3'd7 && grid_data[{cur_row+1'd1, cur_col}]) begin
                                        cur_row <= cur_row + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                            endcase
                        end
                        3'd4: begin
                            case (program[19:16])
                                4'd0: begin
                                    if (cur_col > 3'd0 && grid_data[{cur_row, cur_col-1'd1}]) begin
                                        cur_col <= cur_col - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd1: begin
                                    if (cur_col < 3'd7 && grid_data[{cur_row, cur_col+1'd1}]) begin
                                        cur_col <= cur_col + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd2: begin
                                    if (cur_row > 3'd0 && grid_data[{cur_row-1'd1, cur_col}]) begin
                                        cur_row <= cur_row - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd3: begin
                                    if (cur_row < 3'd7 && grid_data[{cur_row+1'd1, cur_col}]) begin
                                        cur_row <= cur_row + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                            endcase
                        end
                        3'd5: begin
                            case (program[23:20])
                                4'd0: begin
                                    if (cur_col > 3'd0 && grid_data[{cur_row, cur_col-1'd1}]) begin
                                        cur_col <= cur_col - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd1: begin
                                    if (cur_col < 3'd7 && grid_data[{cur_row, cur_col+1'd1}]) begin
                                        cur_col <= cur_col + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd2: begin
                                    if (cur_row > 3'd0 && grid_data[{cur_row-1'd1, cur_col}]) begin
                                        cur_row <= cur_row - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd3: begin
                                    if (cur_row < 3'd7 && grid_data[{cur_row+1'd1, cur_col}]) begin
                                        cur_row <= cur_row + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                            endcase
                        end
                        3'd6: begin
                            case (program[27:24])
                                4'd0: begin
                                    if (cur_col > 3'd0 && grid_data[{cur_row, cur_col-1'd1}]) begin
                                        cur_col <= cur_col - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd1: begin
                                    if (cur_col < 3'd7 && grid_data[{cur_row, cur_col+1'd1}]) begin
                                        cur_col <= cur_col + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd2: begin
                                    if (cur_row > 3'd0 && grid_data[{cur_row-1'd1, cur_col}]) begin
                                        cur_row <= cur_row - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd3: begin
                                    if (cur_row < 3'd7 && grid_data[{cur_row+1'd1, cur_col}]) begin
                                        cur_row <= cur_row + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                            endcase
                        end
                        3'd7: begin
                            case (program[31:28])
                                4'd0: begin
                                    if (cur_col > 3'd0 && grid_data[{cur_row, cur_col-1'd1}]) begin
                                        cur_col <= cur_col - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd1: begin
                                    if (cur_col < 3'd7 && grid_data[{cur_row, cur_col+1'd1}]) begin
                                        cur_col <= cur_col + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd2: begin
                                    if (cur_row > 3'd0 && grid_data[{cur_row-1'd1, cur_col}]) begin
                                        cur_row <= cur_row - 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                                4'd3: begin
                                    if (cur_row < 3'd7 && grid_data[{cur_row+1'd1, cur_col}]) begin
                                        cur_row <= cur_row + 1'd1;
                                        step_count <= step_count + 1'b1;
                                    end
                                end
                            endcase
                        end
                    endcase
                    
                    if (prog_idx == prog_len - 1'b1) begin
                        prog_idx <= 3'd0;
                    end else begin
                        prog_idx <= prog_idx + 1'b1;
                    end
                end
            end
            
            CHECK_CYCLE: begin
                cycle_detected <= 1'b1;
                result <= step_count;
                done <= 1'b1;
            end
            
            DONE: begin
                if (state == SIMULATE && next_state == DONE && !cycle_detected) begin
                    result <= 16'd1;
                end
                done <= 1'b1;
            end
            
            default: begin
                done <= 1'b0;
                result <= 16'd0;
                cycle_detected <= 1'b0;
            end
        endcase
    end
end

endmodule