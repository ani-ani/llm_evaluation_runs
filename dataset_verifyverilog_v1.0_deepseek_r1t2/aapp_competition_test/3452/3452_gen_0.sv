module MazeAnalyzer #(
    parameter N = 8,
    parameter DEG_W = 4,
    parameter SIG_W = 32
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [DEG_W-1:0] degree [0:N-1],
    input wire [N-1:0] adj [0:N-1],
    output reg [SIG_W-1:0] signature [0:N-1],
    output reg done
);

    // State declaration
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    reg [2:0] room_i;
    reg [2:0] neighbor_j;
    reg [SIG_W-1:0] sum;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            room_i <= 3'd0;
            neighbor_j <= 3'd0;
            sum <= {SIG_W{1'b0}};
            for (i = 0; i < N; i = i + 1) begin
                signature[i] <= {SIG_W{1'b0}};
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        room_i <= 3'd0;
                        neighbor_j <= 3'd0;
                        sum <= {SIG_W{1'b0}};
                    end
                end
                
                COMPUTE: begin
                    if (neighbor_j < N) begin
                        if (adj[room_i][neighbor_j]) begin
                            sum <= sum + {{(SIG_W-DEG_W){1'b0}}, degree[neighbor_j]};
                        end
                        neighbor_j <= neighbor_j + 1;
                    end else begin
                        signature[room_i] <= {{(SIG_W-DEG_W){1'b0}}, degree[room_i]} + (sum << 4);
                        
                        if (room_i == (N-1)) begin
                            state <= DONE;
                        end else begin
                            room_i <= room_i + 1;
                            neighbor_j <= 3'd0;
                            sum <= {SIG_W{1'b0}};
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule