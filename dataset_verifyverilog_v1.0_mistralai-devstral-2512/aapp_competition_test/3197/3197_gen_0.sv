module max_participants(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [63:0] edges_flat,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] INCREMENT = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    reg [1:0] state;
    reg [15:0] mask;
    reg [15:0] max_mask;
    reg [3:0] max_count;
    reg [3:0] current_count;
    reg [3:0] i;
    reg valid;
    reg [3:0] latched_n;
    reg [3:0] latched_k;
    reg [63:0] latched_edges;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            mask <= 16'd0;
            max_mask <= 16'd0;
            max_count <= 4'd0;
            current_count <= 4'd0;
            i <= 4'd0;
            valid <= 1'b1;
            latched_n <= 4'd0;
            latched_k <= 4'd0;
            latched_edges <= 64'd0;
            result <= 4'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        latched_n <= n;
                        latched_k <= k;
                        latched_edges <= edges_flat;
                        mask <= 16'd1;
                        max_mask <= (16'd1 << latched_n) - 16'd1;
                        max_count <= 4'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Compute population count
                    current_count <= 4'd0;
                    for (i = 4'd0; i < 16; i = i + 4'd1) begin
                        if (mask[i] == 1'b1) begin
                            current_count <= current_count + 4'd1;
                        end
                    end

                    // Check if population count exceeds k
                    if (current_count > latched_k) begin
                        valid <= 1'b0;
                    end else begin
                        // Check validity
                        valid <= 1'b1;
                        for (i = 4'd0; i < latched_n; i = i + 4'd1) begin
                            if (mask[i] == 1'b1) begin
                                // Get dependency (convert from 1-based to 0-based)
                                reg [3:0] dependency = latched_edges[i*4 +: 4] - 4'd1;
                                if (mask[dependency] == 1'b0) begin
                                    valid <= 1'b0;
                                end
                            end
                        end
                    end

                    // Update max_count if valid and current_count is greater
                    if (valid && (current_count > max_count)) begin
                        max_count <= current_count;
                    end

                    state <= INCREMENT;
                end

                INCREMENT: begin
                    if (mask == max_mask) begin
                        state <= DONE;
                    end else begin
                        mask <= mask + 16'd1;
                        state <= CHECK;
                    end
                end

                DONE: begin
                    result <= max_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule