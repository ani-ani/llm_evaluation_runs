module combinations_gen(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] elements_in [0:3],
    output reg [7:0] result [0:3],
    output reg [3:0] result_len,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SAMPLE = 2'd1;
    localparam [1:0] COUNTING = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Internal registers
    reg [3:0] len_reg;
    reg [7:0] buffer [0:3];
    reg [3:0] counter;
    reg [3:0] next_counter;
    reg [3:0] result_len_reg;
    reg [7:0] result_reg [0:3];
    
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            result_len_reg <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            len_reg <= 4'd0;
            // Initialize buffer
            for (i = 0; i < 4; i = i + 1) begin
                buffer[i] <= 8'd0;
                result_reg[i] <= 8'd0;
                result[i] <= 8'd0;
            end
            result_len <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    counter <= 4'd0;
                    result_len_reg <= 4'd0;
                    if (start) begin
                        len_reg <= len;
                        // Sample input elements
                        for (i = 0; i < 4; i = i + 1) begin
                            if (i < len) begin
                                buffer[i] <= elements_in[i];
                            end else begin
                                buffer[i] <= 8'd0;
                            end
                        end
                    end
                end
                
                SAMPLE: begin
                    // One cycle delay after start
                    counter <= 4'd0;
                    result_len_reg <= 4'd0;
                end
                
                COUNTING: begin
                    // Generate combination
                    counter <= next_counter;
                    result_len_reg <= 4'd0;
                    result_reg[0] <= 8'd0;
                    result_reg[1] <= 8'd0;
                    result_reg[2] <= 8'd0;
                    result_reg[3] <= 8'd0;
                    
                    // Build result based on counter bits
                    if (len_reg > 0 && counter[0]) begin
                        result_reg[0] <= buffer[0];
                        result_len_reg <= result_len_reg + 4'd1;
                    end
                    if (len_reg > 1 && counter[1]) begin
                        result_reg[1] <= buffer[1];
                    end
                    if (len_reg > 2 && counter[2]) begin
                        result_reg[2] <= buffer[2];
                    end
                    if (len_reg > 3 && counter[3]) begin
                        result_reg[3] <= buffer[3];
                    end
                    
                    // Calculate result length (popcount of counter masked by len)
                    if (len_reg > 0 && counter[0]) result_len_reg <= result_len_reg + 4'd1;
                    if (len_reg > 1 && counter[1]) result_len_reg <= result_len_reg + 4'd1;
                    if (len_reg > 2 && counter[2]) result_len_reg <= result_len_reg + 4'd1;
                    if (len_reg > 3 && counter[3]) result_len_reg <= result_len_reg + 4'd1;
                    
                    valid <= 1'b1;
                    done <= 1'b0;
                end
                
                FINISH: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    result_len_reg <= 4'd0;
                    for (i = 0; i < 4; i = i + 1) begin
                        result_reg[i] <= 8'd0;
                    end
                end
            endcase
            
            // Update output ports
            result_len <= result_len_reg;
            for (i = 0; i < 4; i = i + 1) begin
                result[i] <= result_reg[i];
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        next_counter = counter;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SAMPLE;
                end
            end
            
            SAMPLE: begin
                next_state = COUNTING;
            end
            
            COUNTING: begin
                // Next counter value
                next_counter = counter + 4'd1;
                
                // Check if done (all combinations generated)
                if (counter == ((1 << len_reg) - 4'd1)) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule