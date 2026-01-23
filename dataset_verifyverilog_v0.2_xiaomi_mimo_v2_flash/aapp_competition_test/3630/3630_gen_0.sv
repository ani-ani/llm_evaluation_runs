module string_puzzle_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0][7:0] s1,
    input [7:0][7:0] s2,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    
    // Combinational logic for difference calculation
    wire signed [7:0] diff_raw [0:7];
    wire signed [7:0] diff_normalized [0:7];
    wire [7:0] abs_diff [0:7];
    wire [15:0] sum_result;
    
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : gen_diff
            // Calculate raw difference
            assign diff_raw[i] = s2[i] - s1[i];
            
            // Normalize to range [-12, 13] using modulo 26
            // diff_raw[i] % 26, then adjust to [-12, 13]
            wire signed [7:0] mod26;
            assign mod26 = diff_raw[i] % 8'sd26;
            
            // Adjust range: if mod26 > 13, subtract 26
            assign diff_normalized[i] = (mod26 > 8'sd13) ? (mod26 - 8'sd26) : mod26;
            
            // Absolute value
            assign abs_diff[i] = (diff_normalized[i] < 0) ? -diff_normalized[i] : diff_normalized[i];
        end
        
        // Sum all absolute differences
        assign sum_result = abs_diff[0] + abs_diff[1] + abs_diff[2] + abs_diff[3] + 
                           abs_diff[4] + abs_diff[5] + abs_diff[6] + abs_diff[7];
    endgenerate

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                next_state = DONE;
            end
            DONE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = DONE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'h0000;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                COMPUTE: begin
                    result <= sum_result;
                end
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule