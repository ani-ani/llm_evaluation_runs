module superdoku_solver (
    input clk,
    input rst_n, 
    input start,
    input [1:0] k,
    input [1:0] row_idx,
    input [1:0] cell_idx,
    input [1:0] data_in,
    output reg [1:0] grid_out [4][4],
    output reg valid,
    output reg solvable,
    output reg done
);

reg [1:0] grid [4][4];
reg [1:0] temp_row [4];
reg [2:0] state; 
reg [2:0] count; 
reg input_valid;
reg column_valid;
reg [1:0] default_first_row [4] = {2'b00, 2'b01, 2'b10, 2'b11};

always @(posedge clk) begin
    if (!rst_n) begin
        grid <= 0;
        temp_row <= 0;
        state <= 0;
        count <=0;
        input_valid <=0;
        column_valid <=0;
        valid <=0;
        solvable <=0;
        done <=0;
    end else begin
        case(state)
            0: // IDLE
                if (start) begin
                    state <= 1; // LOAD
                    count <=0;
                end
            1: // LOAD: 4 cycles
                if (count <4) begin
                    if (k ==0) begin
                        case(count)
                            0: grid[0][0] <= default_first_row[0];
                            1: grid[0][1] <= default_first_row[1];
                            2: grid[0][2] <= default_first_row[2];
                            3: grid[0][3] <= default_first_row[3];
                        endcase
                    end else begin
                        grid[0][count] <= data_in;
                    end
                    count <= count +1;
                end else begin
                    state <=2; // CHECK
                    count <=0;
                end
            2: // CHECK: 3 cycles
                if (count <3) begin
                    if (count ==0) begin
                        input_valid =1;
                        if (k >=1) begin
                            if (grid[0][0] == grid[0][1] || grid[0][0] == grid[0][2] || grid[0][0] == grid[0][3] || grid[0][1] == grid[0][2] || grid[0][1] == grid[0][3] || grid[0][2] == grid[0][3]) begin
                                input_valid =0;
                            end
                        end
                    end
                    count <= count +1;
                end else begin
                    state <=3; // GENERATE
                    count <=0;
                end
            3: // GENERATE: 3 cycles
                if (count <3) begin
                    case(count)
                        1: begin
                            temp_row[0] = grid[0][3];
                            temp_row[1] = grid[0][0];
                            temp_row[2] = grid[0][1];
                            temp_row[3] = grid[0][2];
                        end
                        2: begin
                            temp_row[0] = grid[0][2];
                            temp_row[1] = grid[0][3];
                            temp_row[2] = grid[0][0];
                            temp_row[3] = grid[0][1];
                        end
                        3: begin
                            temp_row[0] = grid[0][1];
                            temp_row[1] = grid[0][2];
                            temp_row[2] = grid[0][3];
                            temp_row[3] = grid[0][0];
                        end
                    endcase
                    grid[count] <= temp_row;
                    count <= count +1;
                end else begin
                    state <=4; // VERIFY
                    count <=0;
                end
            4: // VERIFY: 2 cycles
                if (count <2) begin
                    if (count ==0) begin
                        column_valid =1;
                        if (grid[0][0] == grid[1][0] || grid[0][0] == grid[2][0] || grid[0][0] == grid[3][0] || grid[1][0] == grid[2][0] || grid[1][0] == grid[3][0] || grid[2][0] == grid[3][0]) begin
                            column_valid =0;
                        end
                        if (grid[0][1] == grid[1][1] || grid[0][1] == grid[2][1] || grid[0][1] == grid[3][1] || grid[1][1] == grid[2][1] || grid[1][1] == grid[3][1] || grid[2][1] == grid[3][1]) begin
                            column_valid =0;
                        end
                        if (grid[0][2] == grid[1][2] || grid[0][2] == grid[2][2] || grid[0][2] == grid[3][2] || grid[1][2] == grid[2][2] || grid[1][2] == grid[3][2] || grid[2][2] == grid[3][2]) begin
                            column_valid =0;
                        end
                        if (grid[0][3] == grid[1][3] || grid[0][3] == grid[2][3] || grid[0][3] == grid[3][3] || grid[1][3] == grid[2][3] || grid[1][3] == grid[3][3] || grid[2][3] == grid[3][3]) begin
                            column_valid =0;
                        end
                    end
                    count <= count +1;
                end else begin
                    state <=5; // DONE
                    count <=0;
                    valid <= input_valid && column_valid;
                    solvable <= valid;
                    done <=1;
                end
            5: // DONE
                done <=1;
        endcase
    end
endmodule