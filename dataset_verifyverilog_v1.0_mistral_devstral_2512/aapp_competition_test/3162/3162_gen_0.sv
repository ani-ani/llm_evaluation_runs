module pixel_counter(
    input clk,
    input rst_n,
    input start,
    input signed [17:0] vertical_t [0:7],
    input signed [17:0] vertical_m [0:7],
    input signed [17:0] vertical_a [0:7],
    input vertical_valid [0:7],
    input signed [17:0] horizontal_t [0:7],
    input signed [17:0] horizontal_m [0:7],
    input signed [17:0] horizontal_a [0:7],
    input horizontal_valid [0:7],
    output reg [5:0] count,
    output reg done
);

    localparam [5:0] IDLE = 6'd0;
    localparam [5:0] COMPUTE = 6'd1;
    localparam [5:0] FINISH = 6'd2;
    
    reg [5:0] state;
    reg [5:0] i;
    reg [5:0] j;
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 6'd0;
            done <= 1'b0;
            i <= 6'd0;
            j <= 6'd0;
            cycle_count <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 6'd0;
                        j <= 6'd0;
                        count <= 6'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    if (vertical_valid[i] && horizontal_valid[j]) begin
                        signed [17:0] d = vertical_t[i] - horizontal_t[j];
                        signed [17:0] k = vertical_a[i] - horizontal_a[j];
                        signed [17:0] lower_bound = k - vertical_m[i];
                        signed [17:0] upper_bound = k + horizontal_m[j];
                        
                        if ((d > lower_bound) && (d < upper_bound)) begin
                            count <= count + 6'd1;
                        end
                    end
                    
                    j <= j + 6'd1;
                    if (j == 6'd8) begin
                        j <= 6'd0;
                        i <= i + 6'd1;
                    end
                    
                    if ((i == 6'd8) || (cycle_count >= MAX_CYCLES)) begin
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