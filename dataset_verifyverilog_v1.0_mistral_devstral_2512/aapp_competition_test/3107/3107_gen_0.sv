module truck_meeting(
    input clk,
    input rst_n,
    input signed [7:0] a1,
    input signed [7:0] a2,
    input signed [7:0] b1,
    input signed [7:0] b2,
    input start,
    output reg meeting,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            meeting <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    reg signed [8:0] T1;
                    reg signed [8:0] T2;
                    reg signed [8:0] numerator;
                    reg signed [8:0] denominator;
                    reg signed [8:0] min_T;
                    reg signed [8:0] two_min_T;
                    reg signed [8:0] diff_a;
                    reg signed [8:0] diff_b;
                    reg signed [8:0] s1;
                    reg signed [8:0] s2;
                    
                    diff_a = a2 - a1;
                    diff_b = b2 - b1;
                    
                    T1 = (diff_a[8] == 1'b0) ? diff_a : -diff_a;
                    T2 = (diff_b[8] == 1'b0) ? diff_b : -diff_b;
                    
                    s1 = (a2 > a1) ? 8'd1 : 8'd-1;
                    s2 = (b2 > b1) ? 8'd1 : 8'd-1;
                    
                    numerator = b1 - a1;
                    denominator = s1 - s2;
                    
                    min_T = (T1 < T2) ? T1 : T2;
                    two_min_T = min_T << 1;
                    
                    if (s1 == s2) begin
                        meeting <= 1'b0;
                    end else begin
                        if (denominator == 8'd2) begin
                            meeting <= (numerator > 8'd0) && (numerator < two_min_T);
                        end else begin
                            meeting <= (numerator < 8'd0) && (numerator > -two_min_T);
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule