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

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] OUTPUT  = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [4:0] counter;           // 0-16 counter
    reg [3:0] rot_count_mod;     // Rotation count modulo 16
    
    // Register file for input array (16 x 8-bit)
    reg [7:0] array_reg [0:15];
    
    // Control signals
    reg load_done;
    reg compute_done;
    reg output_done;
    
    integer i;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            LOAD: begin
                if (load_done) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = LOAD;
                end
            end
            COMPUTE: begin
                if (compute_done) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = COMPUTE;
                end
            end
            OUTPUT: begin
                if (output_done) begin
                    next_state = IDLE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            counter <= 5'd0;
            rot_count_mod <= 4'd0;
            load_done <= 1'b0;
            compute_done <= 1'b0;
            output_done <= 1'b0;
            
            // Initialize all array registers
            for (i = 0; i < 16; i = i + 1) begin
                array_reg[i] <= 8'd0;
            end
            
            // Initialize all output ports
            arr_out_0  <= 8'd0;
            arr_out_1  <= 8'd0;
            arr_out_2  <= 8'd0;
            arr_out_3  <= 8'd0;
            arr_out_4  <= 8'd0;
            arr_out_5  <= 8'd0;
            arr_out_6  <= 8'd0;
            arr_out_7  <= 8'd0;
            arr_out_8  <= 8'd0;
            arr_out_9  <= 8'd0;
            arr_out_10 <= 8'd0;
            arr_out_11 <= 8'd0;
            arr_out_12 <= 8'd0;
            arr_out_13 <= 8'd0;
            arr_out_14 <= 8'd0;
            arr_out_15 <= 8'd0;
            
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    counter <= 5'd0;
                    load_done <= 1'b0;
                    compute_done <= 1'b0;
                    output_done <= 1'b0;
                    
                    if (start) begin
                        busy <= 1'b1;
                        rot_count_mod <= rotation_count % 16;
                    end
                end
                
                LOAD: begin
                    // Load input array into register file
                    case (counter)
                        5'd0:  array_reg[0]  <= arr_in_0;
                        5'd1:  array_reg[1]  <= arr_in_1;
                        5'd2:  array_reg[2]  <= arr_in_2;
                        5'd3:  array_reg[3]  <= arr_in_3;
                        5'd4:  array_reg[4]  <= arr_in_4;
                        5'd5:  array_reg[5]  <= arr_in_5;
                        5'd6:  array_reg[6]  <= arr_in_6;
                        5'd7:  array_reg[7]  <= arr_in_7;
                        5'd8:  array_reg[8]  <= arr_in_8;
                        5'd9:  array_reg[9]  <= arr_in_9;
                        5'd10: array_reg[10] <= arr_in_10;
                        5'd11: array_reg[11] <= arr_in_11;
                        5'd12: array_reg[12] <= arr_in_12;
                        5'd13: array_reg[13] <= arr_in_13;
                        5'd14: array_reg[14] <= arr_in_14;
                        5'd15: array_reg[15] <= arr_in_15;
                    endcase
                    
                    if (counter < 16) begin
                        counter <= counter + 5'd1;
                    end
                    
                    if (counter == 15) begin
                        load_done <= 1'b1;
                        counter <= 5'd0;
                    end
                end
                
                COMPUTE: begin
                    // No computation needed in this cycle,
                    // all calculation done in OUTPUT state
                    compute_done <= 1'b1;
                end
                
                OUTPUT: begin
                    // Assign output based on rotation logic
                    // Element i goes to position (i + rot_count_mod) % 16
                    case (counter)
                        5'd0:  arr_out_0  <= array_reg[(0 + rot_count_mod) % 16];
                        5'd1:  arr_out_1  <= array_reg[(1 + rot_count_mod) % 16];
                        5'd2:  arr_out_2  <= array_reg[(2 + rot_count_mod) % 16];
                        5'd3:  arr_out_3  <= array_reg[(3 + rot_count_mod) % 16];
                        5'd4:  arr_out_4  <= array_reg[(4 + rot_count_mod) % 16];
                        5'd5:  arr_out_5  <= array_reg[(5 + rot_count_mod) % 16];
                        5'd6:  arr_out_6  <= array_reg[(6 + rot_count_mod) % 16];
                        5'd7:  arr_out_7  <= array_reg[(7 + rot_count_mod) % 16];
                        5'd8:  arr_out_8  <= array_reg[(8 + rot_count_mod) % 16];
                        5'd9:  arr_out_9  <= array_reg[(9 + rot_count_mod) % 16];
                        5'd10: arr_out_10 <= array_reg[(10 + rot_count_mod) % 16];
                        5'd11: arr_out_11 <= array_reg[(11 + rot_count_mod) % 16];
                        5'd12: arr_out_12 <= array_reg[(12 + rot_count_mod) % 16];
                        5'd13: arr_out_13 <= array_reg[(13 + rot_count_mod) % 16];
                        5'd14: arr_out_14 <= array_reg[(14 + rot_count_mod) % 16];
                        5'd15: arr_out_15 <= array_reg[(15 + rot_count_mod) % 16];
                    endcase
                    
                    if (counter < 16) begin
                        counter <= counter + 5'd1;
                    end
                    
                    if (counter == 15) begin
                        output_done <= 1'b1;
                        done <= 1'b1;
                        busy <= 1'b0;
                        counter <= 5'd0;
                    end
                end
            endcase
        end
    end

endmodule