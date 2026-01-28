module knight_coordinate_generator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n,
    output reg [10:0] x,
    output reg [1:0] y,
    output reg valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] GENERATE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [9:0] knight_counter;
    reg [9:0] groups;
    reg [1:0] remainder;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            knight_counter <= 10'd0;
            groups <= 10'd0;
            remainder <= 2'd0;
            cycle_count <= 10'd0;
            x <= 11'd0;
            y <= 2'd0;
            valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= GENERATE;
                        groups <= n / 3;
                        remainder <= n % 3;
                        knight_counter <= 10'd0;
                    end
                end
                
                GENERATE: begin
                    valid <= 1'b1;
                    done <= 1'b0;
                    cycle_count <= cycle_count + 10'd1;
                    
                    // Calculate coordinates based on knight_counter
                    if (knight_counter < groups * 3) begin
                        // Group knights
                        reg [9:0] group_index = knight_counter / 3;
                        reg [1:0] knight_in_group = knight_counter % 3;
                        
                        case (knight_in_group)
                            2'd0: begin
                                x <= 2 * group_index;
                                y <= 2'd0;
                            end
                            2'd1: begin
                                x <= 2 * group_index + 1;
                                y <= 2'd0;
                            end
                            2'd2: begin
                                x <= 2 * group_index + 1;
                                y <= 2'd3;
                            end
                        endcase
                    end else begin
                        // Remainder knights
                        reg [9:0] remainder_index = knight_counter - groups * 3;
                        x <= 2 * groups + remainder_index;
                        y <= 2'd0;
                    end
                    
                    // Check if done
                    if (knight_counter == n - 1) begin
                        state <= FINISH;
                    end else begin
                        knight_counter <= knight_counter + 10'd1;
                    end
                end
                
                FINISH: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule