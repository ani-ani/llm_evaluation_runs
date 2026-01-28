module MaxAlternatingSum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [31:0] a [0:15],
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate signals
    reg signed [31:0] d [0:15];
    reg signed [31:0] ev [0:15];
    reg signed [31:0] od [0:15];
    
    // Kadane's algorithm variables
    reg signed [31:0] max_ending_here_ev;
    reg signed [31:0] max_so_far_ev;
    reg signed [31:0] max_ending_here_od;
    reg signed [31:0] max_so_far_od;
    
    reg [3:0] i;
    reg [3:0] j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            for (j = 0; j < 16; j = j + 1) begin
                d[j] <= 32'd0;
                ev[j] <= 32'd0;
                od[j] <= 32'd0;
            end
            
            max_ending_here_ev <= 32'd0;
            max_so_far_ev <= 32'd0;
            max_ending_here_od <= 32'd0;
            max_so_far_od <= 32'd0;
            i <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 4'd0;
                        
                        // Initialize Kadane's variables
                        max_ending_here_ev <= 32'd0;
                        max_so_far_ev <= 32'd0;
                        max_ending_here_od <= 32'd0;
                        max_so_far_od <= 32'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute differences and alternating signs
                    if (i < n - 4'd1) begin
                        // Compute d[i] = |a[i] - a[i+1]|
                        if (a[i] > a[i+1]) begin
                            d[i] <= a[i] - a[i+1];
                        end else begin
                            d[i] <= a[i+1] - a[i];
                        end
                        
                        // Compute ev[i] = d[i] * (-1)^i
                        if (i[0] == 1'b0) begin
                            ev[i] <= d[i];
                        end else begin
                            ev[i] <= -d[i];
                        end
                        
                        // Compute od[i] = d[i] * (-1)^(i+1)
                        if (i[0] == 1'b0) begin
                            od[i] <= -d[i];
                        end else begin
                            od[i] <= d[i];
                        end
                        
                        // Kadane's algorithm for ev
                        if (max_ending_here_ev + ev[i] > ev[i]) begin
                            max_ending_here_ev <= max_ending_here_ev + ev[i];
                        end else begin
                            max_ending_here_ev <= ev[i];
                        end
                        
                        if (max_ending_here_ev > max_so_far_ev) begin
                            max_so_far_ev <= max_ending_here_ev;
                        end
                        
                        // Kadane's algorithm for od
                        if (max_ending_here_od + od[i] > od[i]) begin
                            max_ending_here_od <= max_ending_here_od + od[i];
                        end else begin
                            max_ending_here_od <= od[i];
                        end
                        
                        if (max_ending_here_od > max_so_far_od) begin
                            max_so_far_od <= max_ending_here_od;
                        end
                        
                        i <= i + 4'd1;
                    end else begin
                        // Final comparison
                        if (max_so_far_ev > max_so_far_od) begin
                            result <= max_so_far_ev;
                        end else begin
                            result <= max_so_far_od;
                        end
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