class Astute::DeploymentEngine::SimplePuppet < Astute::DeploymentEngine
  # It is trivial puppet run. It's assumed that user has prepared site.pp
  #   with all required parameters for modules
  def deploy_piece(nodes, attrs, retries=2, change_node_status=true)
    return false unless validate_nodes(nodes)
    @ctx.reporter.report nodes_status(nodes, 'deploying', {'progress' => 0})
    Astute::PuppetdDeployer.deploy(@ctx, nodes, retries, change_node_status)
    nodes_roles = nodes.map { |n| { n['uid'] => n['role'] } }
    Astute.logger.info "#{@ctx.task_id}: Finished deployment of nodes => roles: #{nodes_roles.inspect}"
  end
end
