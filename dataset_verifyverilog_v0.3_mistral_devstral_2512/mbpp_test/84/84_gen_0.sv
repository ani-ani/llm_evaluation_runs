module newman_conway_seq(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    output reg [7:0] result,
    output reg done
);

    reg [4:0] i;
    reg [7:0] p [15:0];
    reg [1:0] state;
    reg [2:0] substate;
    
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE_STATE = 2'b10;
    
    localparam READ1 = 3'b001;
    localparam READ2 = 3'b010;
    localparam WRITE = 3'b011;
    
    reg [7:0] val_i_minus_1;
    reg [7:0] p_of_val;
    reg [7:0] p_of_diff;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            substate <= READ1;
            done <= 1'b0;
            result <= 8'd0;
            i <= 5'd0;
            p[0] <= 8'd1;
            p[1] <= 8'd1;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && n >= 5'd1) begin
                        if (n == 5'd1 || n == 5'd2) begin
                            result <= 8'd1;
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            i <= 5'd3;
                            substate <= READ1;
                            state <= COMPUTE;
                        end
                    end
                end
                
                COMPUTE: begin
                    case (substate)
                        READ1: begin
                            val_i_minus_1 <= p[i-2];
                            substate <= READ2;
                        end
                        
                        READ2: begin
                            p_of_val <= p[val_i_minus_1 - 1];
                            p_of_diff <= p[i - val_i_minus_1 - 1];
                            substate <= WRITE;
                        end
                        
                        WRITE: begin
                            p[i-1] <= p_of_val + p_of_diff;
                            
                            if (i == n) begin
                                result <= p_of_val + p_of_diff;
                                done <= 1'b1;
                                state <= DONE_STATE;
                            end else begin
                                i <= i + 5'd1;
                                substate <= READ1;
                            end
                        end
                    endcase
                end
                
                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule