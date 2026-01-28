module rotate_array (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in_0, arr_in_1, arr_in_2, arr_in_3,
                     arr_in_4, arr_in_5, arr_in_6, arr_in_7,
                     arr_in_8, arr_in_9, arr_in_10, arr_in_11,
                     arr_in_12, arr_in_13, arr_in_14, arr_in_15,
    input wire [3:0] rotation_count,
    output reg [7:0] arr_out_0, arr_out_1, arr_out_2, arr_out_3,
                     arr_out_4, arr_out_5, arr_out_6, arr_out_7,
                     arr_out_8, arr_out_9, arr_out_10, arr_out_11,
                     arr_out_12, arr_out_13, arr_out_14, arr_out_15,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    reg [1:0] state, next_state;
    reg [3:0] index;  // 4-bit counter for 16 elements
    reg [7:0] arr_reg [0:15];  // Internal register file
    reg [3:0] rot_count_reg;  // Registered rotation count
    reg [3:0] max_index = 4'd15;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            busy <= 1'b0;
            
            // Initialize all output registers
            arr_out_0 <= 8'd0;
            arr_out_1 <= 8'd0;
            arr_out_2 <= 8'd0;
            arr_out_3 <= 8'd0;
            arr_out_4 <= 8'd0;
            arr_out_5 <= 8'd0;
            arr_out_6 <= 8'd0;
            arr_out_7 <= 8'd0;
            arr_out_8 <= 8'd0;
            arr_out_9 <= 8'd0;
            arr_out_10 <= 8'd0;
            arr_out_11 <= 8'd0;
            arr_out_12 <= 8'd0;
            arr_out_13 <= 8'd0;
            arr_out_14 <= 8'd0;
            arr_out_15 <= 8'd0;
            
            // Initialize internal register file
            arr_reg[0] <= 8'd0;
            arr_reg[1] <= 8'd0;
            arr_reg[2] <= 8'd0;
            arr_reg[3] <= 8'd0;
            arr_reg[4] <= 8'd0;
            arr_reg[5] <= 8'd0;
            arr_reg[6] <= 8'd0;
            arr_reg[7] <= 8'd0;
            arr_reg[8] <= 8'd0;
            arr_reg[9] <= 8'd0;
            arr_reg[10] <= 8'd0;
            arr_reg[11] <= 8'd0;
            arr_reg[12] <= 8'd0;
            arr_reg[13] <= 8'd0;
            arr_reg[14] <= 8'd0;
            arr_reg[15] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        // Load input array into register file
                        arr_reg[0] <= arr_in_0;
                        arr_reg[1] <= arr_in_1;
                        arr_reg[2] <= arr_in_2;
                        arr_reg[3] <= arr_in_3;
                        arr_reg[4] <= arr_in_4;
                        arr_reg[5] <= arr_in_5;
                        arr_reg[6] <= arr_in_6;
                        arr_reg[7] <= arr_in_7;
                        arr_reg[8] <= arr_in_8;
                        arr_reg[9] <= arr_in_9;
                        arr_reg[10] <= arr_in_10;
                        arr_reg[11] <= arr_in_11;
                        arr_reg[12] <= arr_in_12;
                        arr_reg[13] <= arr_in_13;
                        arr_reg[14] <= arr_in_14;
                        arr_reg[15] <= arr_in_15;
                        
                        rot_count_reg <= rotation_count;
                        index <= 4'd0;
                        next_state <= COMPUTE;
                        busy <= 1'b1;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    // Compute destination index: (i + rotation_count) % 16
                    reg [3:0] dest_index;
                    dest_index = (index + rot_count_reg) % 16;
                    
                    // Output to appropriate port
                    case (dest_index)
                        4'd0: arr_out_0 <= arr_reg[index];
                        4'd1: arr_out_1 <= arr_reg[index];
                        4'd2: arr_out_2 <= arr_reg[index];
                        4'd3: arr_out_3 <= arr_reg[index];
                        4'd4: arr_out_4 <= arr_reg[index];
                        4'd5: arr_out_5 <= arr_reg[index];
                        4'd6: arr_out_6 <= arr_reg[index];
                        4'd7: arr_out_7 <= arr_reg[index];
                        4'd8: arr_out_8 <= arr_reg[index];
                        4'd9: arr_out_9 <= arr_reg[index];
                        4'd10: arr_out_10 <= arr_reg[index];
                        4'd11: arr_out_11 <= arr_reg[index];
                        4'd12: arr_out_12 <= arr_reg[index];
                        4'd13: arr_out_13 <= arr_reg[index];
                        4'd14: arr_out_14 <= arr_reg[index];
                        4'd15: arr_out_15 <= arr_reg[index];
                        default: ;
                    endcase
                    
                    // Increment index
                    if (index == max_index) begin
                        index <= 4'd0;
                        next_state <= OUTPUT;
                    end else begin
                        index <= index + 4'd1;
                        next_state <= COMPUTE;
                    end
                end
                
                OUTPUT: begin
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule