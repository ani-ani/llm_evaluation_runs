module ice_cream_optimizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] k,
    input [7:0] a,
    input [7:0] b,
    input [7:0] t [0:7],
    input [7:0] u [0:7][0:7],
    output reg [15:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] current_scoop;
    reg [15:0] best_tastiness;
    reg [15:0] current_cost;
    reg [15:0] max_ratio;
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;
            current_scoop <= 8'd0;
            best_tastiness <= 16'd0;
            current_cost <= 16'd0;
            max_ratio <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE;
                        done <= 1'b0;
                        current_scoop <= 8'd1;
                        best_tastiness <= 16'd0;
                        max_ratio <= 16'd0;
                    end
                end
                
                COMPUTE: begin
                    if (current_scoop <= n && current_scoop <= 8'd16) begin
                        best_tastiness <= 16'd0;
                        
                        for (i = 0; i < k; i = i + 1) begin
                            for (j = 0; j < k; j = j + 1) begin
                                if (current_scoop == 8'd1) begin
                                    if ((t[i] << 8) > best_tastiness) begin
                                        best_tastiness <= (t[i] << 8);
                                    end
                                end else if (current_scoop == 8'd2) begin
                                    if ((t[i] << 8) + ((t[j] + u[j][i]) << 8) > best_tastiness) begin
                                        best_tastiness <= (t[i] << 8) + ((t[j] + u[j][i]) << 8);
                                    end
                                end
                            end
                        end
                        
                        current_cost <= ((a * current_scoop + b) << 8);
                        
                        if (current_cost > 0 && best_tastiness > 0) begin
                            if (best_tastiness / current_cost > max_ratio) begin
                                max_ratio <= best_tastiness / current_cost;
                            end
                        end
                        
                        current_scoop <= current_scoop + 8'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    if (best_tastiness > 0) begin
                        result <= max_ratio;
                    end else begin
                        result <= 16'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule