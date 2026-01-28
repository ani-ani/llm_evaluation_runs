module mod_exp(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] p,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [7:0] bit_counter;
    reg [15:0] current_result;
    reg [7:0] current_n;
    reg [7:0] current_p;
    reg [15:0] temp_product;
    reg [15:0] temp_mod;
    reg [7:0] i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            bit_counter <= 8'd0;
            current_result <= 16'd0;
            current_n <= 8'd0;
            current_p <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    if (start) begin
                        current_n <= n;
                        current_p <= p;
                        current_result <= 16'd1;  // 2^0 = 1
                        bit_counter <= 8'd0;
                        next_state <= CALCULATE;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALCULATE: begin
                    // Square the current result
                    temp_product <= current_result * current_result;
                    
                    // Compute temp_product % current_p
                    temp_mod <= temp_product;
                    if (current_p != 8'd0) begin
                        for (i = 0; i < 8; i = i + 1) begin
                            if (temp_mod >= current_p) begin
                                temp_mod <= temp_mod - current_p;
                            end
                        end
                    end else begin
                        temp_mod <= 16'd0;
                    end
                    
                    current_result <= temp_mod;
                    
                    // Check current bit of n
                    if (current_n[bit_counter]) begin
                        temp_product <= current_result * 2;
                        
                        // Compute temp_product % current_p
                        temp_mod <= temp_product;
                        if (current_p != 8'd0) begin
                            for (i = 0; i < 8; i = i + 1) begin
                                if (temp_mod >= current_p) begin
                                    temp_mod <= temp_mod - current_p;
                                end
                            end
                        end else begin
                            temp_mod <= 16'd0;
                        end
                        
                        current_result <= temp_mod;
                    end
                    
                    bit_counter <= bit_counter + 8'd1;
                    
                    if (bit_counter == 8'd7) begin
                        next_state <= DONE_STATE;
                    end else begin
                        next_state <= CALCULATE;
                    end
                end

                DONE_STATE: begin
                    result <= current_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end

endmodule