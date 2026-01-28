module garbage_disposal(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [9:0] k,
    input wire [9:0] a_in,
    output reg [19:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [3:0] day_counter;
    reg [9:0] carry;
    reg [19:0] bag_accumulator;
    reg [9:0] total;
    reg [19:0] bags_used;
    reg [9:0] carry_next;
    reg last_day;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            day_counter <= 4'd0;
            carry <= 10'd0;
            bag_accumulator <= 20'd0;
            result <= 20'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        day_counter <= 4'd0;
                        carry <= 10'd0;
                        bag_accumulator <= 20'd0;
                    end
                end
                
                PROCESS: begin
                    last_day = (day_counter == n - 4'd1);
                    
                    // Calculate total garbage for current day
                    total = a_in + carry;
                    
                    // Calculate bags used
                    if (last_day) begin
                        // Last day: use ceil(total / k)
                        if (total == 10'd0) begin
                            bags_used = 20'd0;
                        end else if (total[9:0] < k) begin
                            bags_used = 20'd1;
                        end else begin
                            bags_used = (total + k - 10'd1) / k;
                        end
                        carry_next = 10'd0;
                    end else begin
                        // Not last day: use floor(total / k) with special case
                        if (total == 10'd0) begin
                            bags_used = 20'd0;
                        end else if (carry > 10'd0 && total < k) begin
                            bags_used = 20'd1;
                            carry_next = total;
                        end else begin
                            bags_used = total / k;
                            carry_next = total % k;
                        end
                    end
                    
                    // Update accumulator and carry
                    bag_accumulator = bag_accumulator + bags_used;
                    carry = carry_next;
                    
                    // Move to next day or finish
                    if (day_counter == n - 4'd1) begin
                        state <= FINISH;
                    end else begin
                        day_counter = day_counter + 4'd1;
                    end
                end
                
                FINISH: begin
                    // Handle remaining carry after all days
                    if (carry > 10'd0) begin
                        bag_accumulator = bag_accumulator + 20'd1;
                    end
                    
                    result <= bag_accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule