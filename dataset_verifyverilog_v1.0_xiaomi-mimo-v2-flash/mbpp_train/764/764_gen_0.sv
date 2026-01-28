module digit_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str_data [15:0],
    input wire [15:0] str_valid,
    output reg [7:0] result,
    output reg done
);
    // State declarations for FSM
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Internal registers for captured inputs
    reg [7:0] str_data_reg [15:0];
    reg [15:0] str_valid_reg;
    
    // Combinational wires for digit detection
    wire [15:0] is_digit;
    wire [7:0] digit_count;
    
    // Generate digit detection for each position
    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : digit_check
            assign is_digit[i] = str_valid_reg[i] && 
                                 (str_data_reg[i] >= 8'h30) && 
                                 (str_data_reg[i] <= 8'h39);
        end
    endgenerate
    
    // Count set bits (digit count) using binary addition tree
    assign digit_count = is_digit[0] + is_digit[1] + is_digit[2] + is_digit[3] +
                         is_digit[4] + is_digit[5] + is_digit[6] + is_digit[7] +
                         is_digit[8] + is_digit[9] + is_digit[10] + is_digit[11] +
                         is_digit[12] + is_digit[13] + is_digit[14] + is_digit[15];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            str_valid_reg <= 16'd0;
            // Initialize array using loop
            begin : init_array
                integer j;
                for (j = 0; j < 16; j = j + 1) begin
                    str_data_reg[j] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Capture inputs for computation
                        str_valid_reg <= str_valid;
                        // Capture str_data array using loop
                        begin : capture_array
                            integer k;
                            for (k = 0; k < 16; k = k + 1) begin
                                str_data_reg[k] <= str_data[k];
                            end
                        end
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Combinational computation completed
                    result <= digit_count;
                    
                    // Move to finish state
                    // Always have a path to FINISH
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule