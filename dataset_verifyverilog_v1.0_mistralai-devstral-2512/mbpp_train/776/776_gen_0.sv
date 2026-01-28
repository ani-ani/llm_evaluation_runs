module vowel_neighbor_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:15],
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Internal registers for processing
    reg [7:0] str_reg [0:15];
    reg [4:0] count;
    reg [3:0] index;
    
    // Vowel detection
    wire is_vowel [0:15];
    integer i;
    always @(*) begin
        for (i = 0; i < 16; i = i + 1) begin
            is_vowel[i] = (str_reg[i] == 8'h61) ||  // 'a'
                          (str_reg[i] == 8'h65) ||  // 'e'
                          (str_reg[i] == 8'h69) ||  // 'i'
                          (str_reg[i] == 8'h6f) ||  // 'o'
                          (str_reg[i] == 8'h75);   // 'u'
        end
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            count <= 5'd0;
            index <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                str_reg[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Latch input string
                        for (i = 0; i < 16; i = i + 1) begin
                            str_reg[i] <= str[i];
                        end
                        state <= PROCESS;
                        count <= 5'd0;
                        index <= 4'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current character is not a vowel
                    if (!is_vowel[index]) begin
                        // Check left neighbor (if exists)
                        if (index > 0 && is_vowel[index - 1]) begin
                            count <= count + 5'd1;
                        end
                        // Check right neighbor (if exists)
                        else if (index < 15 && is_vowel[index + 1]) begin
                            count <= count + 5'd1;
                        end
                    end
                    
                    // Move to next index
                    if (index == 4'd15) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                    end
                end
                
                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule