module triple_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n,
    output reg [23:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COUNT   = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [9:0] counter;
    reg [9:0] cnt_0, cnt_1, cnt_2;
    reg [23:0] temp_result;
    
    // FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 10'd0;
            cnt_0 <= 10'd0;
            cnt_1 <= 10'd0;
            cnt_2 <= 10'd0;
            result <= 24'd0;
            done <= 1'b0;
            temp_result <= 24'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNT;
                        counter <= 10'd1;
                        cnt_0 <= 10'd0;
                        cnt_1 <= 10'd0;
                        cnt_2 <= 10'd0;
                    end
                end
                
                COUNT: begin
                    // Count residues for current counter value
                    if (counter % 3 == 0) begin
                        cnt_0 <= cnt_0 + 10'd1;
                    end else if (counter % 3 == 1) begin
                        cnt_1 <= cnt_1 + 10'd1;
                    end else begin
                        cnt_2 <= cnt_2 + 10'd1;
                    end
                    
                    // Move to next number or finish counting
                    if (counter == n) begin
                        state <= COMPUTE;
                    end else begin
                        counter <= counter + 10'd1;
                    end
                end
                
                COMPUTE: begin
                    // Calculate combinations
                    // C(cnt_0, 3) = cnt_0*(cnt_0-1)*(cnt_0-2)/6
                    temp_result <= (cnt_0 * (cnt_0 - 10'd1) * (cnt_0 - 10'd2)) >> 3;
                    
                    // Add C(cnt_1, 3)
                    temp_result <= temp_result + ((cnt_1 * (cnt_1 - 10'd1) * (cnt_1 - 10'd2)) >> 3);
                    
                    // Add C(cnt_2, 3)
                    temp_result <= temp_result + ((cnt_2 * (cnt_2 - 10'd1) * (cnt_2 - 10'd2)) >> 3);
                    
                    // Add cnt_0 * cnt_1 * cnt_2
                    temp_result <= temp_result + cnt_0 * cnt_1 * cnt_2;
                    
                    // Add cnt_0 * C(cnt_1, 2)
                    temp_result <= temp_result + cnt_0 * ((cnt_1 * (cnt_1 - 10'd1)) >> 1);
                    
                    // Add cnt_1 * C(cnt_2, 2)
                    temp_result <= temp_result + cnt_1 * ((cnt_2 * (cnt_2 - 10'd1)) >> 1);
                    
                    // Output result and done signal
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Handle n < 3 case (result should be 0)
    always @(*) begin
        if (n < 10'd3) begin
            result = 24'd0;
        end
    end

endmodule