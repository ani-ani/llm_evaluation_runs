module frog_jumps #(
    parameter N = 8,
    parameter SPOT_WIDTH = 8,
    parameter IDX_WIDTH = 4
)(
    input clk,
    input rst_n,
    input start,
    input [N*SPOT_WIDTH-1:0] spots_flat,
    output reg [IDX_WIDTH-1:0] max_index,
    output reg done
);
    
    reg [SPOT_WIDTH-1:0] spots [0:N-1];
    reg [N-1:0] reachable;
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOOP = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state;
    reg [IDX_WIDTH-1:0] i;
    reg [IDX_WIDTH-1:0] j;
    
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_index <= {IDX_WIDTH{1'b0}};
            done <= 1'b0;
            for (k = 0; k < N; k = k + 1) begin
                spots[k] <= {SPOT_WIDTH{1'b0}};
            end
            reachable <= {N{1'b0}};
            i <= {IDX_WIDTH{1'b0}};
            j <= {IDX_WIDTH{1'b0}};
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        for (k = 0; k < N; k = k + 1) begin
                            spots[k] <= spots_flat[k*SPOT_WIDTH +: SPOT_WIDTH];
                        end
                        reachable <= { {N-1{1'b0}}, 1'b1 };
                        max_index <= {IDX_WIDTH{1'b0}};
                        i <= {IDX_WIDTH{1'b0}};
                        j <= (N > 1) ? ({{IDX_WIDTH-1{1'b0}}, 1'b1}) : {IDX_WIDTH{1'b0}};
                        done <= 1'b0;
                        state <= LOOP;
                    end else begin
                        done <= 1'b0;
                    end
                end
                
                LOOP: begin
                    if (i < j && j < N) begin
                        if (reachable[i] && (spots[i] + spots[j] == (j - i))) begin
                            reachable[j] <= 1'b1;
                            if (j > max_index) begin
                                max_index <= j;
                            end
                        end
                    end
                    
                    if (j < N - 1) begin
                        j <= j + 1'b1;
                    end else if (i < N - 2) begin
                        i <= i + 1'b1;
                        j <= i + 1'b1;
                    end else begin
                        state <= COMPLETE;
                        done <= 1'b1;
                    end
                end
                
                COMPLETE: begin
                    state <= COMPLETE;
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule