module elementwise_subtraction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] counter;
    reg [3:0] max_count;
    
    // Control signal for computation
    wire compute_done;
    assign compute_done = (counter >= max_count);
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 4'd0;
            max_count <= 4'd0;
            done <= 1'b0;
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 4'd0;
                    if (start) begin
                        max_count <= len;
                    end
                end
                
                COMPUTE: begin
                    // Perform element-wise subtraction
                    if (counter < max_count) begin
                        result[counter] <= arr1[counter] - arr2[counter];
                        counter <= counter + 4'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && (len > 4'd0)) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTE: begin
                if (compute_done) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule