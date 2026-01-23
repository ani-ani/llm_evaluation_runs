module holmes_deduction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] known_events,
    input wire [7:0] implications [7:0],
    output reg [7:0] certain_events,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] current_certain;
    reg [7:0] next_certain;
    reg [2:0] iteration_count;
    localparam [2:0] MAX_ITERATIONS = 3'd7;

    // Deduction logic
    always @(*) begin
        next_certain = current_certain;
        
        // Forward propagation
        integer i, j;
        for (i = 0; i < 8; i = i + 1) begin
            if (current_certain[i]) begin
                for (j = 0; j < 8; j = j + 1) begin
                    if (implications[i][j]) begin
                        next_certain[j] = 1'b1;
                    end
                end
            end
        end
        
        // Backward propagation for single causes
        for (j = 0; j < 8; j = j + 1) begin
            if (current_certain[j]) begin
                integer cause_count = 0;
                integer last_cause = -1;
                for (i = 0; i < 8; i = i + 1) begin
                    if (implications[i][j]) begin
                        cause_count = cause_count + 1;
                        last_cause = i;
                    end
                end
                if (cause_count == 1 && last_cause >= 0) begin
                    next_certain[last_cause] = 1'b1;
                end
            end
        end
        
        // Common cause propagation
        for (j = 0; j < 8; j = j + 1) begin
            if (current_certain[j]) begin
                reg [7:0] causes_of_j = 8'b0;
                for (i = 0; i < 8; i = i + 1) begin
                    if (implications[i][j]) begin
                        causes_of_j[i] = 1'b1;
                    end
                end
                
                reg [7:0] common_causes = 8'b11111111;
                for (i = 0; i < 8; i = i + 1) begin
                    if (causes_of_j[i]) begin
                        reg [7:0] causes_of_i = 8'b0;
                        integer k;
                        for (k = 0; k < 8; k = k + 1) begin
                            if (implications[k][i]) begin
                                causes_of_i[k] = 1'b1;
                            end
                        end
                        common_causes = common_causes & causes_of_i;
                    end
                end
                
                next_certain = next_certain | common_causes;
            end
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_certain <= 8'd0;
            iteration_count <= 3'd0;
            done <= 1'b0;
            certain_events <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        current_certain <= known_events;
                        iteration_count <= 3'd0;
                    end
                end
                
                COMPUTE: begin
                    if (current_certain == next_certain || iteration_count >= MAX_ITERATIONS) begin
                        state <= FINISH;
                    end else begin
                        current_certain <= next_certain;
                        iteration_count <= iteration_count + 1'b1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    certain_events <= current_certain;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule