module flower_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] L_new,
    input wire [7:0] R_new,
    input wire [3:0] len,
    input wire [7:0] L_arr_0,
    input wire [7:0] L_arr_1,
    input wire [7:0] L_arr_2,
    input wire [7:0] L_arr_3,
    input wire [7:0] L_arr_4,
    input wire [7:0] L_arr_5,
    input wire [7:0] L_arr_6,
    input wire [7:0] L_arr_7,
    input wire [7:0] L_arr_8,
    input wire [7:0] L_arr_9,
    input wire [7:0] L_arr_10,
    input wire [7:0] L_arr_11,
    input wire [7:0] L_arr_12,
    input wire [7:0] L_arr_13,
    input wire [7:0] L_arr_14,
    input wire [7:0] L_arr_15,
    input wire [7:0] R_arr_0,
    input wire [7:0] R_arr_1,
    input wire [7:0] R_arr_2,
    input wire [7:0] R_arr_3,
    input wire [7:0] R_arr_4,
    input wire [7:0] R_arr_5,
    input wire [7:0] R_arr_6,
    input wire [7:0] R_arr_7,
    input wire [7:0] R_arr_8,
    input wire [7:0] R_arr_9,
    input wire [7:0] R_arr_10,
    input wire [7:0] R_arr_11,
    input wire [7:0] R_arr_12,
    input wire [7:0] R_arr_13,
    input wire [7:0] R_arr_14,
    input wire [7:0] R_arr_15,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    reg [7:0] L_new_reg;
    reg [7:0] R_new_reg;
    reg [3:0] len_reg;
    reg [3:0] plant_idx;
    reg [7:0] flower_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            L_new_reg <= 8'd0;
            R_new_reg <= 8'd0;
            len_reg <= 4'd0;
            plant_idx <= 4'd0;
            flower_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        L_new_reg <= L_new;
                        R_new_reg <= R_new;
                        len_reg <= len;
                        plant_idx <= 4'd0;
                        flower_count <= 8'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all plants
                    if (plant_idx >= len_reg) begin
                        state <= FINISH;
                    end else begin
                        // Check L_new stem intersection
                        if (check_intersection(plant_idx, L_new_reg)) begin
                            flower_count <= flower_count + 8'd1;
                        end
                        
                        // Check R_new stem intersection
                        if (check_intersection(plant_idx, R_new_reg)) begin
                            flower_count <= flower_count + 8'd1;
                        end
                        
                        plant_idx <= plant_idx + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= flower_count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Function to check intersection for a given x coordinate
    function check_intersection;
        input [3:0] idx;
        input [7:0] x;
        begin
            case (idx)
                4'd0:  check_intersection = (L_arr_0 < x) && (x < R_arr_0) && (4'd1 > 0);
                4'd1:  check_intersection = (L_arr_1 < x) && (x < R_arr_1) && (4'd2 > 0);
                4'd2:  check_intersection = (L_arr_2 < x) && (x < R_arr_2) && (4'd3 > 0);
                4'd3:  check_intersection = (L_arr_3 < x) && (x < R_arr_3) && (4'd4 > 0);
                4'd4:  check_intersection = (L_arr_4 < x) && (x < R_arr_4) && (4'd5 > 0);
                4'd5:  check_intersection = (L_arr_5 < x) && (x < R_arr_5) && (4'd6 > 0);
                4'd6:  check_intersection = (L_arr_6 < x) && (x < R_arr_6) && (4'd7 > 0);
                4'd7:  check_intersection = (L_arr_7 < x) && (x < R_arr_7) && (4'd8 > 0);
                4'd8:  check_intersection = (L_arr_8 < x) && (x < R_arr_8) && (4'd9 > 0);
                4'd9:  check_intersection = (L_arr_9 < x) && (x < R_arr_9) && (4'd10 > 0);
                4'd10: check_intersection = (L_arr_10 < x) && (x < R_arr_10) && (4'd11 > 0);
                4'd11: check_intersection = (L_arr_11 < x) && (x < R_arr_11) && (4'd12 > 0);
                4'd12: check_intersection = (L_arr_12 < x) && (x < R_arr_12) && (4'd13 > 0);
                4'd13: check_intersection = (L_arr_13 < x) && (x < R_arr_13) && (4'd14 > 0);
                4'd14: check_intersection = (L_arr_14 < x) && (x < R_arr_14) && (4'd15 > 0);
                4'd15: check_intersection = (L_arr_15 < x) && (x < R_arr_15) && (4'd16 > 0);
                default: check_intersection = 1'b0;
            endcase
        end
    endfunction

endmodule