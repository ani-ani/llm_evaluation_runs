module friendship_clique (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [7:0] adj [0:7],
    output reg [3:0] steps,
    output reg [7:0] sequence [0:7],
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [2:0] current_guest;
    reg [7:0] temp_adj [0:7];
    reg [3:0] step_count;
    reg [7:0] sequence_reg [0:7];
    reg [2:0] seq_index;

    integer i, j, k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            steps <= 4'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                sequence[i] <= 8'd0;
                sequence_reg[i] <= 8'd0;
                temp_adj[i] <= 8'd0;
            end
            current_guest <= 3'd0;
            step_count <= 4'd0;
            seq_index <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= COMPUTE;
                        step_count <= 4'd0;
                        seq_index <= 3'd0;
                        for (i = 0; i < 8; i = i + 1) begin
                            sequence_reg[i] <= 8'd0;
                            temp_adj[i] <= adj[i];
                        end
                        current_guest <= 3'd0;
                        done <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    if (is_complete(temp_adj, n)) begin
                        state <= FINISH;
                    end else if (current_guest < n) begin
                        if (has_neighbors(temp_adj, current_guest, n)) begin
                            sequence_reg[seq_index] <= current_guest + 1;
                            seq_index <= seq_index + 1;
                            step_count <= step_count + 4'd1;
                            
                            for (i = 0; i < n; i = i + 1) begin
                                if (temp_adj[current_guest][i]) begin
                                    for (j = i + 1; j < n; j = j + 1) begin
                                        if (temp_adj[current_guest][j]) begin
                                            temp_adj[i][j] <= 1;
                                            temp_adj[j][i] <= 1;
                                        end
                                    end
                                end
                            end
                        end
                        current_guest <= current_guest + 3'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    steps <= step_count;
                    for (i = 0; i < 8; i = i + 1) begin
                        sequence[i] <= sequence_reg[i];
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    function automatic is_complete;
        input [7:0] adj_matrix [0:7];
        input [2:0] size;
        begin
            is_complete = 1'b1;
            for (i = 0; i < size; i = i + 1) begin
                for (j = i + 1; j < size; j = j + 1) begin
                    if (!adj_matrix[i][j]) begin
                        is_complete = 1'b0;
                    end
                end
            end
        end
    endfunction

    function automatic has_neighbors;
        input [7:0] adj_matrix [0:7];
        input [2:0] guest;
        input [2:0] size;
        begin
            has_neighbors = 1'b0;
            for (i = 0; i < size; i = i + 1) begin
                if (adj_matrix[guest][i] && i != guest) begin
                    has_neighbors = 1'b1;
                end
            end
        end
    endfunction

endmodule